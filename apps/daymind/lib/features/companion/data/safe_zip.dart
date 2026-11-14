import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

class CharacterZipFailure implements Exception {
  const CharacterZipFailure(this.code, this.message);
  final String code, message;
  @override
  String toString() => message;
}

class CharacterZip {
  CharacterZip._(this.files, this.expandedBytes);
  final Map<String, Uint8List> files;
  final int expandedBytes;
  static const maxArchiveBytes = 16 * 1024 * 1024;
  static const maxExpandedBytes = 32 * 1024 * 1024;
  static const maxFileBytes = 8 * 1024 * 1024;
  static const maxEntries = 64;
  static const maxDepth = 4;
  static const maxInflationRatio = 300;

  /// Reads only single-volume store/deflate ZIPs. No archive path is extracted.
  /// Call off the UI isolate for user imports; normalized assets install later.
  static CharacterZip read(Uint8List bytes) => _ZipReader(bytes).read();
}

class CharacterCrc32 {
  static final _table = List<int>.generate(256, (i) {
    var n = i;
    for (var bit = 0; bit < 8; bit++) {
      n = n.isOdd ? 0xedb88320 ^ (n >> 1) : n >> 1;
    }
    return n;
  }, growable: false);
  static int of(List<int> bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc = _table[(crc ^ byte) & 255] ^ (crc >> 8);
    }
    return crc ^ 0xffffffff;
  }
}

class _ZipEntry {
  const _ZipEntry(
    this.path,
    this.rawName,
    this.directory,
    this.flags,
    this.method,
    this.crc,
    this.compressed,
    this.expanded,
    this.offset,
  );
  final String path;
  final Uint8List rawName;
  final bool directory;
  final int flags, method, crc, compressed, expanded, offset;
}

class _ZipReader {
  _ZipReader(this.bytes) : data = ByteData.sublistView(bytes);
  final Uint8List bytes;
  final ByteData data;
  Never fail(String code, String message) =>
      throw CharacterZipFailure(code, message);
  void need(int at, int count, [int? limit]) {
    if (at < 0 || count < 0 || at + count > (limit ?? bytes.length)) {
      fail(
        'integrity',
        'Gói ZIP bị thiếu dữ liệu hoặc có cấu trúc không hợp lệ.',
      );
    }
  }

  int u16(int at) {
    need(at, 2);
    return data.getUint16(at, Endian.little);
  }

  int u32(int at) {
    need(at, 4);
    return data.getUint32(at, Endian.little);
  }

  Uint8List slice(int at, int length) {
    need(at, length);
    return Uint8List.sublistView(bytes, at, at + length);
  }

  void extra(int at, int count) {
    final end = at + count;
    need(at, count);
    while (at < end) {
      need(at, 4, end);
      final id = u16(at), size = u16(at + 2);
      if (id == 1) fail('unsupported', 'Gói ZIP64 chưa được hỗ trợ.');
      at += 4;
      need(at, size, end);
      at += size;
    }
  }

  String path(Uint8List raw, bool directory) {
    if (raw.isEmpty || raw.length > 200 || raw.any((b) => b < 32 || b > 126)) {
      fail(
        'unsafe_path',
        'Tên tệp trong gói cần dùng chữ ASCII và dài tối đa 200 byte.',
      );
    }
    final original = ascii.decode(raw);
    final value = directory
        ? original.substring(0, original.length - 1)
        : original;
    final segments = value.split('/');
    if (segments.length > CharacterZip.maxDepth ||
        segments.any(
          (s) =>
              s.isEmpty ||
              s == '.' ||
              s == '..' ||
              s.endsWith('.') ||
              s.endsWith(' ') ||
              !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(s) ||
              RegExp(
                r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\.|$)',
                caseSensitive: false,
              ).hasMatch(s),
        )) {
      fail(
        'unsafe_path',
        'Gói có đường dẫn không an toàn hoặc không được hỗ trợ.',
      );
    }
    return value;
  }

  CharacterZip read() {
    if (bytes.length < 22 || bytes.length > CharacterZip.maxArchiveBytes) {
      fail('quota', 'Gói ZIP tối đa 16 MiB và cần có nội dung hợp lệ.');
    }
    var end = -1;
    for (
      var at = bytes.length - 22;
      at >= math.max(0, bytes.length - 22 - 65535);
      at--
    ) {
      if (u32(at) == 0x06054b50 && at + 22 + u16(at + 20) == bytes.length) {
        end = at;
        break;
      }
    }
    if (end < 0 ||
        u16(end + 4) != 0 ||
        u16(end + 6) != 0 ||
        u16(end + 8) != u16(end + 10)) {
      fail(
        'unsupported',
        'Chỉ nhận gói ZIP một phần, không chia thành nhiều tệp.',
      );
    }
    final count = u16(end + 10),
        centralSize = u32(end + 12),
        central = u32(end + 16);
    if (count < 1 || count > CharacterZip.maxEntries) {
      fail('quota', 'Gói cần từ 1 đến 64 mục.');
    }
    if (central + centralSize != end) {
      fail('integrity', 'Danh mục gói ZIP không hợp lệ.');
    }
    need(central, centralSize, end);
    final entries = <_ZipEntry>[], paths = <String, bool>{};
    var at = central, expandedTotal = 0;
    for (var i = 0; i < count; i++) {
      need(at, 46, end);
      if (u32(at) != 0x02014b50) {
        fail('integrity', 'Danh mục gói ZIP không hợp lệ.');
      }
      final version = u16(at + 6),
          flags = u16(at + 8),
          method = u16(at + 10),
          crc = u32(at + 16),
          compressed = u32(at + 20),
          expanded = u32(at + 24),
          nameLength = u16(at + 28),
          extraLength = u16(at + 30),
          commentLength = u16(at + 32),
          external = u32(at + 38),
          offset = u32(at + 42);
      if (version > 20 ||
          flags & ~0x080e != 0 ||
          (method != 0 && method != 8) ||
          u16(at + 34) != 0) {
        fail(
          'unsupported',
          'Gói không được mã hóa, chia phần hoặc dùng kiểu nén không hỗ trợ.',
        );
      }
      need(at + 46, nameLength + extraLength + commentLength, end);
      final name = slice(at + 46, nameLength),
          directory = name.isNotEmpty && name.last == 47;
      final nameString = path(name, directory),
          canonical = nameString.toLowerCase();
      final mode = external >> 16, kind = mode & 0xf000;
      if ((external & 0x400) != 0 ||
          (kind != 0 && kind != 0x8000 && kind != 0x4000) ||
          (kind == 0x4000 && !directory) ||
          (kind == 0x8000 && directory)) {
        fail('unsafe_path', 'Gói không được chứa liên kết hoặc tệp đặc biệt.');
      }
      if (paths.containsKey(canonical) ||
          paths.entries.any(
            (e) =>
                (!e.value && canonical.startsWith('${e.key}/')) ||
                (!directory && e.key.startsWith('$canonical/')),
          )) {
        fail(
          'unsafe_path',
          'Gói có tên trùng, khác chữ hoa/thường hoặc đường dẫn xung đột.',
        );
      }
      paths[canonical] = directory;
      extra(at + 46 + nameLength, extraLength);
      expandedTotal += expanded;
      if (expanded > CharacterZip.maxFileBytes ||
          compressed > CharacterZip.maxArchiveBytes ||
          expandedTotal > CharacterZip.maxExpandedBytes ||
          (expanded > 0 &&
              (compressed == 0 ||
                  expanded > compressed * CharacterZip.maxInflationRatio))) {
        fail(
          'quota',
          'Gói vượt giới hạn 8 MiB/tệp, 32 MiB giải nén hoặc tỷ lệ nén an toàn.',
        );
      }
      if ((directory && expanded != 0) ||
          (method == 0 && compressed != expanded)) {
        fail('integrity', 'Kích thước tệp trong gói ZIP không hợp lệ.');
      }
      entries.add(
        _ZipEntry(
          nameString,
          name,
          directory,
          flags,
          method,
          crc,
          compressed,
          expanded,
          offset,
        ),
      );
      at += 46 + nameLength + extraLength + commentLength;
    }
    if (at != end) fail('integrity', 'Danh mục gói ZIP có dữ liệu thừa.');
    entries.sort((a, b) => a.offset.compareTo(b.offset));
    final ranges = <_ZipEntry, (int, int)>{};
    var expected = 0;
    for (final entry in entries) {
      if (entry.offset != expected) {
        fail(
          'integrity',
          'Các tệp trong ZIP bị chồng lấn hoặc có dữ liệu thừa.',
        );
      }
      final record = local(entry, central);
      ranges[entry] = record;
      expected = record.$2;
    }
    if (expected != central) {
      fail('integrity', 'Gói ZIP có dữ liệu ngoài danh mục.');
    }
    final files = <String, Uint8List>{};
    for (final entry in entries) {
      final content = inflate(entry, ranges[entry]!.$1);
      if (!entry.directory) files[entry.path] = content.asUnmodifiableView();
    }
    if (files.isEmpty) fail('integrity', 'Gói ZIP không có tệp nội dung.');
    return CharacterZip._(Map.unmodifiable(files), expandedTotal);
  }

  (int, int) local(_ZipEntry e, int central) {
    final at = e.offset;
    need(at, 30, central);
    if (u32(at) != 0x04034b50 ||
        u16(at + 4) > 20 ||
        u16(at + 6) != e.flags ||
        u16(at + 8) != e.method) {
      fail('integrity', 'Thông tin tệp ZIP không nhất quán.');
    }
    final hasDescriptor = e.flags & 8 != 0;
    final crc = u32(at + 14),
        compressed = u32(at + 18),
        expanded = u32(at + 22),
        nameLength = u16(at + 26),
        extraLength = u16(at + 28);
    if ((!hasDescriptor &&
            (crc != e.crc ||
                compressed != e.compressed ||
                expanded != e.expanded)) ||
        (hasDescriptor &&
            ((crc != 0 && crc != e.crc) ||
                (compressed != 0 && compressed != e.compressed) ||
                (expanded != 0 && expanded != e.expanded)))) {
      fail(
        'integrity',
        'Kích thước hoặc kiểm tra toàn vẹn ZIP không nhất quán.',
      );
    }
    need(at + 30, nameLength + extraLength, central);
    final name = slice(at + 30, nameLength);
    if (name.length != e.rawName.length ||
        !List.generate(
          name.length,
          (i) => name[i] == e.rawName[i],
        ).every((v) => v)) {
      fail('integrity', 'Tên tệp ZIP không nhất quán.');
    }
    extra(at + 30 + nameLength, extraLength);
    final start = at + 30 + nameLength + extraLength;
    need(start, e.compressed, central);
    var end = start + e.compressed;
    if (hasDescriptor) {
      need(end, 12, central);
      if (u32(end) == 0x08074b50 &&
          end + 16 <= central &&
          u32(end + 4) == e.crc) {
        end += 4;
      }
      need(end, 12, central);
      if (u32(end) != e.crc ||
          u32(end + 4) != e.compressed ||
          u32(end + 8) != e.expanded) {
        fail('integrity', 'Thông tin kết thúc tệp ZIP không hợp lệ.');
      }
      end += 12;
    }
    return (start, end);
  }

  Uint8List inflate(_ZipEntry entry, int start) {
    Uint8List result;
    if (entry.method == 0) {
      result = Uint8List.fromList(slice(start, entry.compressed));
    } else {
      final output = _BoundedZipOutput(entry.expanded);
      try {
        final decoder = ZLibDecoder(raw: true).startChunkedConversion(output);
        for (var at = start; at < start + entry.compressed; at += 32768) {
          decoder.add(
            slice(at, math.min(32768, start + entry.compressed - at)),
          );
        }
        decoder.close();
        result = output.bytes.takeBytes();
      } on CharacterZipFailure {
        rethrow;
      } catch (_) {
        fail('integrity', 'Dữ liệu nén trong ZIP bị lỗi.');
      }
    }
    if (result.length != entry.expanded ||
        CharacterCrc32.of(result) != entry.crc) {
      fail('integrity', 'Tệp ZIP bị lỗi kích thước hoặc kiểm tra toàn vẹn.');
    }
    return result;
  }
}

class _BoundedZipOutput implements Sink<List<int>> {
  _BoundedZipOutput(this.limit);
  final int limit;
  final bytes = BytesBuilder();
  int count = 0;
  @override
  void add(List<int> chunk) {
    if (chunk.length > limit - count) {
      throw const CharacterZipFailure(
        'quota',
        'Dữ liệu giải nén vượt giới hạn đã khai báo.',
      );
    }
    count += chunk.length;
    bytes.add(chunk);
  }

  @override
  void close() {}
}
