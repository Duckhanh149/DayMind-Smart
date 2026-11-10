import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/features/companion/data/image_preflight.dart';
import 'package:daymind_smart/features/companion/data/safe_zip.dart';

Uint8List pngChunk(String type, List<int> payload) {
  final length = ByteData(4)..setUint32(0, payload.length, Endian.big);
  final content = Uint8List.fromList([...ascii.encode(type), ...payload]);
  final crc = ByteData(4)..setUint32(0, CharacterCrc32.of(content), Endian.big);
  return Uint8List.fromList([
    ...length.buffer.asUint8List(),
    ...content,
    ...crc.buffer.asUint8List(),
  ]);
}

Uint8List gif(int count, {int width = 1, int frameWidth = 1}) {
  final header = ByteData(13);
  for (var i = 0; i < 6; i++) {
    header.setUint8(i, 'GIF89a'.codeUnitAt(i));
  }
  header.setUint16(6, width, Endian.little);
  header.setUint16(8, 1, Endian.little);
  header.setUint8(10, 0x80);
  return Uint8List.fromList([
    ...header.buffer.asUint8List(),
    0,
    0,
    0,
    255,
    255,
    255,
    for (var i = 0; i < count; i++) ...[
      0x2c,
      0,
      0,
      0,
      0,
      frameWidth & 255,
      frameWidth >> 8,
      1,
      0,
      0,
      2,
      2,
      0x44,
      1,
      0,
    ],
    0x3b,
  ]);
}

Uint8List riff(List<Uint8List> chunks) {
  final output = Uint8List.fromList([
    ...ascii.encode('RIFF'),
    0,
    0,
    0,
    0,
    ...ascii.encode('WEBP'),
    for (final c in chunks) ...c,
  ]);
  ByteData.sublistView(output).setUint32(4, output.length - 8, Endian.little);
  return output;
}

List<Uint8List> webpChunks(Uint8List source) {
  final result = <Uint8List>[];
  for (var at = 12; at < source.length;) {
    final size = ByteData.sublistView(source).getUint32(at + 4, Endian.little);
    final end = at + 8 + size + (size & 1);
    result.add(Uint8List.fromList(source.sublist(at, end)));
    at = end;
  }
  return result;
}

void main() {
  test(
    'parses real static PNG/lossless/lossy WebP and GIF/WebP animation',
    () async {
      for (final fixture in [
        'metadata.png',
        'static.webp',
        'lossy.webp',
        'three_frames.gif',
        'three_frames.webp',
      ]) {
        final probe = CharacterImageProbe.inspect(
          await File('test/fixtures/$fixture').readAsBytes(),
        );
        expect((probe.width, probe.height), (8, 8));
        expect(probe.frameCount, fixture.startsWith('three') ? 3 : 1);
        expect(probe.durationsMs.every((d) => d >= 84 && d <= 5000), isTrue);
      }
    },
  );
  test('decoder PNG copy strips private/compressed metadata without mutating source', () async {
    final source = await File('test/fixtures/metadata.png').readAsBytes();
    final probe = CharacterImageProbe.inspect(source, expectedFormat: 'png');
    expect(latin1.decode(source), contains('Private source note'));
    expect(
      latin1.decode(probe.decoderBytes),
      isNot(contains('Private source note')),
    );
    expect(probe.decoderBytes.length, lessThan(source.length));
    expect(() => probe.decoderBytes[0] = 0, throwsUnsupportedError);
    expect(CharacterImageProbe.inspect(probe.decoderBytes).width, 8);
  });
  test('rejects APNG declared frame bombs and oversized dimensions before codec construction', () async {
    final source = await File('test/fixtures/metadata.png').readAsBytes();
    final control = ByteData(8)..setUint32(0, 0x7fffffff, Endian.big);
    final animated = Uint8List.fromList([
      ...source.sublist(0, 33),
      ...pngChunk('acTL', control.buffer.asUint8List()),
      ...source.sublist(33),
    ]);
    expect(
      () => CharacterImageProbe.inspect(animated),
      throwsA(isA<CharacterImageFailure>()),
    );
    final header = Uint8List.fromList(source.sublist(16, 29));
    ByteData.sublistView(header).setUint32(0, 2049, Endian.big);
    final oversized = Uint8List.fromList([
      ...source.sublist(0, 8),
      ...pngChunk('IHDR', header),
      ...source.sublist(33),
    ]);
    expect(
      () => CharacterImageProbe.inspect(oversized),
      throwsA(isA<CharacterImageFailure>()),
    );
  });
  test('caps GIF frame metadata and logical/frame bounds before invoking a native decoder', () {
    expect(CharacterImageProbe.inspect(gif(120)).frameCount, 120);
    for (final bytes in [
      gif(121),
      gif(1, width: 1025),
      gif(1, frameWidth: 2),
      gif(1).sublist(0, 25),
    ]) {
      expect(
        () => CharacterImageProbe.inspect(bytes),
        throwsA(isA<CharacterImageFailure>()),
      );
    }
  });
  test(
    'checks PNG CRC, extension/magic agreement, RIFF length and trailing data',
    () async {
      final png = await File('test/fixtures/metadata.png').readAsBytes();
      expect(
        () => CharacterImageProbe.inspect(png, expectedFormat: 'gif'),
        throwsA(isA<CharacterImageFailure>()),
      );
      png[24] ^= 1;
      expect(
        () => CharacterImageProbe.inspect(png),
        throwsA(isA<CharacterImageFailure>()),
      );
      final webp = await File('test/fixtures/static.webp').readAsBytes();
      expect(
        () => CharacterImageProbe.inspect(Uint8List.fromList([...webp, 1])),
        throwsA(isA<CharacterImageFailure>()),
      );
      expect(
        () => CharacterImageProbe.inspect(Uint8List.fromList([...gif(1), 1])),
        throwsA(isA<CharacterImageFailure>()),
      );
      expect(
        () => CharacterImageProbe.inspect(
          Uint8List(CharacterImageProbe.maxBytes + 1),
        ),
        throwsA(isA<CharacterImageFailure>()),
      );
    },
  );
  test(
    'caps WebP ANMF count and checks its actual bitstream dimensions',
    () async {
      final chunks = webpChunks(
        await File('test/fixtures/three_frames.webp').readAsBytes(),
      );
      final header = chunks
          .where((c) => ascii.decode(c.sublist(0, 4)) != 'ANMF')
          .toList();
      final frame = chunks.firstWhere(
        (c) => ascii.decode(c.sublist(0, 4)) == 'ANMF',
      );
      expect(
        CharacterImageProbe.inspect(
          riff([...header, ...List.generate(120, (_) => frame)]),
        ).frameCount,
        120,
      );
      expect(
        () => CharacterImageProbe.inspect(
          riff([...header, ...List.generate(121, (_) => frame)]),
        ),
        throwsA(isA<CharacterImageFailure>()),
      );
      final wrong = Uint8List.fromList(frame)
        ..[14] = 0
        ..[15] = 0
        ..[16] = 0;
      expect(
        () => CharacterImageProbe.inspect(riff([...header, wrong])),
        throwsA(isA<CharacterImageFailure>()),
      );
    },
  );
}
