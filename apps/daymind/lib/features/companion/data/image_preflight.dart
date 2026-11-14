import 'dart:convert';
import 'dart:typed_data';

import 'safe_zip.dart' show CharacterCrc32;

class CharacterImageFailure implements Exception {
  const CharacterImageFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class CharacterImageProbe {
  CharacterImageProbe._(
    this.format,
    this.width,
    this.height,
    List<int> durations,
    Uint8List decoderBytes,
  ) : durationsMs = List.unmodifiable(durations),
      decoderBytes = decoderBytes.asUnmodifiableView();
  final String format;
  final int width, height;
  final List<int> durationsMs;
  final Uint8List decoderBytes;
  int get frameCount => durationsMs.length;
  static const maxBytes = 16 * 1024 * 1024;
  static const maxFrames = 120;
  static const animatedMaxDimension = 1024;
  static const maxDimension = 4096;
  static int duration(int ms) => ms <= 0 ? 125 : ms.clamp(84, 5000);

  /// Bounds native codec metadata before creating a Flutter/OS image decoder.
  /// Discards non-pixel metadata only in the decoder copy; callers retain source.
  static CharacterImageProbe inspect(
    Uint8List source, {
    String? expectedFormat,
  }) {
    if (source.isEmpty || source.length > maxBytes) {
      throw const CharacterImageFailure('Ảnh trong gói tối đa 16 MiB.');
    }
    final reader = _ImageReader(source);
    final probe = source.length >= 8 && source[0] == 137
        ? reader.png()
        : source.length >= 6 &&
              ascii.decode(source.sublist(0, 3), allowInvalid: true) == 'GIF'
        ? reader.gif()
        : source[0] == 255 && source.length > 1 && source[1] == 216
        ? reader.jpeg()
        : source[0] == 66 && source.length > 1 && source[1] == 77
        ? reader.bmp()
        : reader.webp();
    if (expectedFormat != null &&
        (expectedFormat.toLowerCase() == 'jpg'
                ? 'jpeg'
                : expectedFormat.toLowerCase()) !=
            probe.format) {
      throw const CharacterImageFailure('Đuôi tệp không khớp định dạng ảnh.');
    }
    return probe;
  }
}

class _ImageReader {
  _ImageReader(this.bytes) : data = ByteData.sublistView(bytes);
  final Uint8List bytes;
  final ByteData data;
  Never fail([
    String message = 'Ảnh bị lỗi hoặc có cấu trúc chưa được hỗ trợ.',
  ]) => throw CharacterImageFailure(message);
  void need(int at, int count, [int? end]) {
    if (at < 0 || count < 0 || at + count > (end ?? bytes.length)) fail();
  }

  int le16(int at) {
    need(at, 2);
    return data.getUint16(at, Endian.little);
  }

  int le24(int at) {
    need(at, 3);
    return bytes[at] | bytes[at + 1] << 8 | bytes[at + 2] << 16;
  }

  int le32(int at) {
    need(at, 4);
    return data.getUint32(at, Endian.little);
  }

  int be32(int at) {
    need(at, 4);
    return data.getUint32(at, Endian.big);
  }

  String text(int at, int count) {
    need(at, count);
    return ascii.decode(bytes.sublist(at, at + count), allowInvalid: true);
  }

  void dimensions(int width, int height, {bool animated = false}) {
    final max = animated
        ? CharacterImageProbe.animatedMaxDimension
        : CharacterImageProbe.maxDimension;
    if (width < 1 || height < 1 || width > max || height > max) {
      fail('Ảnh tĩnh/sprite tối đa 4096²; GIF/WebP động tối đa 1024² pixel.');
    }
  }

  void frameLimit(int count) {
    if (count > CharacterImageProbe.maxFrames) {
      fail('Hoạt ảnh tối đa 120 khung hình.');
    }
  }

  CharacterImageProbe jpeg() {
    need(0, 4);
    if (bytes[bytes.length - 2] != 255 || bytes.last != 217) fail();
    var at = 2;
    while (at < bytes.length) {
      if (bytes[at++] != 255) fail();
      while (at < bytes.length && bytes[at] == 255) {
        at++;
      }
      need(at, 1);
      final marker = bytes[at++];
      if (marker == 0xda || marker == 0xd9) fail();
      need(at, 2);
      final size = data.getUint16(at, Endian.big);
      if (size < 2) fail();
      need(at, size);
      if ({0xc0, 0xc1, 0xc2}.contains(marker)) {
        if (size < 8 || bytes[at + 2] != 8) fail();
        final h = data.getUint16(at + 3, Endian.big),
            w = data.getUint16(at + 5, Endian.big);
        dimensions(w, h);
        return CharacterImageProbe._('jpeg', w, h, [125], bytes);
      }
      at += size;
    }
    fail();
  }

  CharacterImageProbe bmp() {
    need(0, 54);
    final offset = le32(10), header = le32(14);
    if (header < 40 || header > 124) fail();
    need(14, header);
    final w = data.getInt32(18, Endian.little),
        h = data.getInt32(22, Endian.little).abs(),
        bits = le16(28);
    dimensions(w, h);
    if (le16(26) != 1 ||
        !{24, 32}.contains(bits) ||
        le32(30) != 0 ||
        offset < 14 + header) {
      fail();
    }
    final rowBytes = ((w * bits + 31) ~/ 32) * 4;
    need(offset, rowBytes * h);
    return CharacterImageProbe._('bmp', w, h, [125], bytes);
  }

  CharacterImageProbe png() {
    need(0, 33);
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (!List.generate(8, (i) => bytes[i] == signature[i]).every((v) => v)) {
      fail();
    }
    final out = BytesBuilder()..add(signature);
    var at = 8,
        width = 0,
        height = 0,
        ihdr = false,
        pixels = false,
        ended = false,
        palette = false;
    while (at < bytes.length) {
      need(at, 12);
      final size = be32(at), kind = text(at + 4, 4), end = at + 12 + size;
      need(at, size + 12);
      if (!RegExp(r'^[A-Za-z]{4}$').hasMatch(kind) ||
          CharacterCrc32.of(
                Uint8List.sublistView(bytes, at + 4, at + 8 + size),
              ) !=
              be32(at + 8 + size)) {
        fail();
      }
      if (!ihdr && kind != 'IHDR') fail();
      if (kind == 'acTL' || kind == 'fcTL' || kind == 'fdAT') {
        fail('PNG động chưa được hỗ trợ. Hãy dùng GIF, WebP động hoặc sprite.');
      }
      if (kind == 'IHDR') {
        if (ihdr || size != 13) fail();
        ihdr = true;
        width = be32(at + 8);
        height = be32(at + 12);
        dimensions(width, height);
      } else if (kind == 'PLTE') {
        if (palette || pixels || size < 3 || size > 768 || size % 3 != 0) {
          fail();
        }
        palette = true;
      } else if (kind == 'IDAT') {
        pixels = true;
      } else if (kind == 'IEND') {
        if (size != 0 || !pixels || end != bytes.length) fail();
        ended = true;
      } else if (kind == 'tRNS') {
        if (pixels || size > 256) fail();
      } else if (kind.codeUnitAt(0) < 97) {
        fail('Ảnh PNG dùng thành phần không được hỗ trợ.');
      }
      // Compressed ICC/text/EXIF are not needed to render an imported character.
      if (const {'IHDR', 'PLTE', 'IDAT', 'tRNS', 'IEND'}.contains(kind)) {
        out.add(Uint8List.sublistView(bytes, at, end));
      }
      at = end;
    }
    if (!ended) fail();
    return CharacterImageProbe._('png', width, height, [125], out.takeBytes());
  }

  int subBlocks(int at) {
    while (true) {
      need(at, 1);
      final count = bytes[at++];
      need(at, count);
      at += count;
      if (count == 0) return at;
    }
  }

  CharacterImageProbe gif() {
    need(0, 13);
    if (text(0, 6) != 'GIF87a' && text(0, 6) != 'GIF89a') fail();
    final width = le16(6), height = le16(8), packed = bytes[10];
    dimensions(width, height, animated: true);
    var at = 13;
    if (packed & 128 != 0) {
      final colors = 1 << ((packed & 7) + 1);
      if (bytes[11] >= colors) fail();
      need(at, colors * 3);
      at += colors * 3;
    }
    var delay = 125, ended = false;
    final durations = <int>[];
    while (at < bytes.length) {
      final tag = bytes[at++];
      if (tag == 0x3b) {
        if (at != bytes.length) fail();
        ended = true;
        break;
      } else if (tag == 0x21) {
        need(at, 1);
        final label = bytes[at++];
        if (label == 0xf9) {
          need(at, 6);
          if (bytes[at] != 4 ||
              bytes[at + 5] != 0 ||
              bytes[at + 1] & 0xe0 != 0 ||
              ((bytes[at + 1] >> 2) & 7) > 3) {
            fail();
          }
          delay = CharacterImageProbe.duration(le16(at + 2) * 10);
          at += 6;
        } else if (label == 0xff || label == 0xfe) {
          at = subBlocks(at);
        } else {
          fail('GIF có phần mở rộng chưa được hỗ trợ.');
        }
      } else if (tag == 0x2c) {
        need(at, 9);
        final x = le16(at),
            y = le16(at + 2),
            w = le16(at + 4),
            h = le16(at + 6),
            flags = bytes[at + 8];
        if (w < 1 ||
            h < 1 ||
            x + w > width ||
            y + h > height ||
            flags & 0x18 != 0) {
          fail();
        }
        at += 9;
        if (flags & 128 != 0) {
          final length = (1 << ((flags & 7) + 1)) * 3;
          need(at, length);
          at += length;
        }
        need(at, 1);
        if (bytes[at] < 2 || bytes[at] > 8) fail();
        at = subBlocks(at + 1);
        durations.add(delay);
        frameLimit(durations.length);
        delay = 125;
      } else {
        fail();
      }
    }
    if (!ended || durations.isEmpty) fail();
    return CharacterImageProbe._(
      'gif',
      width,
      height,
      durations,
      Uint8List.fromList(bytes),
    );
  }

  (int, int) bitstream(String kind, int at, int length) {
    if (kind == 'VP8 ') {
      need(at, 10, at + length);
      if (bytes[at] & 1 != 0 ||
          bytes[at + 3] != 157 ||
          bytes[at + 4] != 1 ||
          bytes[at + 5] != 42) {
        fail();
      }
      final w = le16(at + 6), h = le16(at + 8);
      if (w & 0xc000 != 0 || h & 0xc000 != 0) fail();
      return (w, h);
    }
    need(at, 5, at + length);
    if (bytes[at] != 0x2f) fail();
    final word = le32(at + 1);
    if (word >> 29 != 0) fail();
    return (1 + (word & 0x3fff), 1 + ((word >> 14) & 0x3fff));
  }

  void frameBody(int at, int end, int width, int height) {
    var images = 0, alpha = false;
    while (at < end) {
      need(at, 8, end);
      final kind = text(at, 4),
          size = le32(at + 4),
          next = at + 8 + size + (size & 1);
      need(at + 8, size + (size & 1), end);
      if (kind == 'ALPH') {
        if (alpha || images != 0 || size == 0) fail();
        alpha = true;
      } else if (kind == 'VP8 ' || kind == 'VP8L') {
        final dims = bitstream(kind, at + 8, size);
        if (++images != 1 ||
            dims.$1 != width ||
            dims.$2 != height ||
            (alpha && kind == 'VP8L')) {
          fail();
        }
      } else {
        fail();
      }
      at = next;
    }
    if (images != 1) fail();
  }

  CharacterImageProbe webp() {
    need(0, 12);
    if (text(0, 4) != 'RIFF' ||
        text(8, 4) != 'WEBP' ||
        le32(4) + 8 != bytes.length) {
      fail();
    }
    final kept = BytesBuilder();
    var at = 12,
        width = 0,
        height = 0,
        extended = false,
        animated = false,
        animationHeader = false,
        staticImages = 0;
    final durations = <int>[];
    while (at < bytes.length) {
      need(at, 8);
      final kind = text(at, 4),
          size = le32(at + 4),
          start = at + 8,
          next = start + size + (size & 1);
      need(start, size + (size & 1));
      if (kind == 'VP8X') {
        if (extended ||
            at != 12 ||
            size != 10 ||
            bytes[start] & 0xc1 != 0 ||
            bytes[start + 1] != 0 ||
            bytes[start + 2] != 0 ||
            bytes[start + 3] != 0) {
          fail();
        }
        extended = true;
        animated = bytes[start] & 2 != 0;
        width = le24(start + 4) + 1;
        height = le24(start + 7) + 1;
        dimensions(width, height, animated: animated);
      } else if (kind == 'ANIM') {
        if (!animated || animationHeader || size != 6 || durations.isNotEmpty) {
          fail();
        }
        animationHeader = true;
      } else if (kind == 'ANMF') {
        if (!animated || !animationHeader || size < 16) fail();
        final x = le24(start) * 2,
            y = le24(start + 3) * 2,
            w = le24(start + 6) + 1,
            h = le24(start + 9) + 1;
        if (x + w > width || y + h > height || bytes[start + 15] & ~3 != 0) {
          fail();
        }
        frameBody(start + 16, start + size, w, h);
        durations.add(CharacterImageProbe.duration(le24(start + 12)));
        frameLimit(durations.length);
      } else if (kind == 'VP8 ' || kind == 'VP8L') {
        if (animated || ++staticImages != 1) fail();
        final dims = bitstream(kind, start, size);
        if (extended && (dims.$1 != width || dims.$2 != height)) fail();
        width = dims.$1;
        height = dims.$2;
        dimensions(width, height);
      } else if (kind == 'ALPH') {
        if (animated || staticImages != 0 || size == 0) fail();
      } else if (!const {'ICCP', 'EXIF', 'XMP '}.contains(kind)) {
        fail();
      }
      if (!const {'ICCP', 'EXIF', 'XMP '}.contains(kind)) {
        final chunk = Uint8List.fromList(bytes.sublist(at, next));
        if (kind == 'VP8X') {
          chunk[8] &= 0x12; // Drop metadata flags in decoder copy.
        }
        kept.add(chunk);
      }
      at = next;
    }
    if (animated ? durations.isEmpty || staticImages != 0 : staticImages != 1) {
      fail();
    }
    final chunks = kept.takeBytes(), header = ByteData(12);
    for (var i = 0; i < 4; i++) {
      header.setUint8(i, 'RIFF'.codeUnitAt(i));
      header.setUint8(i + 8, 'WEBP'.codeUnitAt(i));
    }
    header.setUint32(4, chunks.length + 4, Endian.little);
    final cleaned =
        (BytesBuilder()
              ..add(header.buffer.asUint8List())
              ..add(chunks))
            .takeBytes();
    return CharacterImageProbe._(
      'webp',
      width,
      height,
      animated ? durations : [125],
      cleaned,
    );
  }
}
