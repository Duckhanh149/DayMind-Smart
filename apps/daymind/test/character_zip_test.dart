import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/features/companion/data/safe_zip.dart';

class Entry {
  Entry(
    this.name,
    List<int> data, {
    this.method = 8,
    this.flags = 0,
    this.version = 20,
    this.attributes = 0,
    this.size,
    this.localName,
    this.localOffset,
    this.extra = const [],
    this.crc,
  }) : data = Uint8List.fromList(data);
  final String name;
  final Uint8List data;
  final int method, flags, version, attributes;
  final int? size, localOffset, crc;
  final String? localName;
  final List<int> extra;
}

Uint8List zip(
  List<Entry> entries, {
  bool descriptor = false,
  bool signature = true,
  List<int> prefix = const [],
}) {
  final output = BytesBuilder()..add(prefix), central = BytesBuilder();
  void u16(ByteData b, int at, int value) =>
      b.setUint16(at, value, Endian.little);
  void u32(ByteData b, int at, int value) =>
      b.setUint32(at, value, Endian.little);
  for (final e in entries) {
    final name = utf8.encode(e.name),
        localName = utf8.encode(e.localName ?? e.name),
        flags = e.flags | 0x800 | (descriptor ? 8 : 0),
        compressed = e.method == 8
            ? ZLibEncoder(raw: true).convert(e.data)
            : e.data,
        size = e.size ?? e.data.length,
        crc = e.crc ?? CharacterCrc32.of(e.data),
        offset = output.length;
    final h = ByteData(30);
    u32(h, 0, 0x04034b50);
    u16(h, 4, e.version);
    u16(h, 6, flags);
    u16(h, 8, e.method);
    u32(h, 14, descriptor ? 0 : crc);
    u32(h, 18, descriptor ? 0 : compressed.length);
    u32(h, 22, descriptor ? 0 : size);
    u16(h, 26, localName.length);
    u16(h, 28, e.extra.length);
    output
      ..add(h.buffer.asUint8List())
      ..add(localName)
      ..add(e.extra)
      ..add(compressed);
    if (descriptor) {
      final d = ByteData(signature ? 16 : 12), base = signature ? 4 : 0;
      if (signature) u32(d, 0, 0x08074b50);
      u32(d, base, crc);
      u32(d, base + 4, compressed.length);
      u32(d, base + 8, size);
      output.add(d.buffer.asUint8List());
    }
    final c = ByteData(46);
    u32(c, 0, 0x02014b50);
    u16(c, 4, 0x314);
    u16(c, 6, e.version);
    u16(c, 8, flags);
    u16(c, 10, e.method);
    u32(c, 16, crc);
    u32(c, 20, compressed.length);
    u32(c, 24, size);
    u16(c, 28, name.length);
    u16(c, 30, e.extra.length);
    u32(c, 38, e.attributes);
    u32(c, 42, e.localOffset ?? offset);
    central
      ..add(c.buffer.asUint8List())
      ..add(name)
      ..add(e.extra);
  }
  final start = output.length, size = central.length;
  output.add(central.takeBytes());
  final end = ByteData(22);
  u32(end, 0, 0x06054b50);
  u16(end, 8, entries.length);
  u16(end, 10, entries.length);
  u32(end, 12, size);
  u32(end, 16, start);
  return (output..add(end.buffer.asUint8List())).takeBytes();
}

Matcher failure([String? code]) => throwsA(
  isA<CharacterZipFailure>().having(
    (e) => code == null || e.code == code,
    'failure category',
    true,
  ),
);

void main() {
  test(
    'reads a standard-library ZIP and matches the published CRC32 vector',
    () async {
      expect(CharacterCrc32.of(utf8.encode('123456789')), 0xcbf43926);
      final original = await File('test/fixtures/valid_character.zip')
          .readAsBytes();
      final archive = CharacterZip.read(original);
      expect(archive.files.keys, ['manifest.json', 'assets/sheet.png']);
      expect(
        jsonDecode(utf8.decode(archive.files['manifest.json']!))['version'],
        1,
      );
      final first = archive.files['assets/sheet.png']!.first;
      original.fillRange(0, original.length, 0);
      expect(archive.files['assets/sheet.png']!.first, first);
      expect(
        () => archive.files['extra'] = Uint8List(0),
        throwsUnsupportedError,
      );
      expect(
        () => archive.files['manifest.json']![0] = 0,
        throwsUnsupportedError,
      );
    },
  );
  test(
    'store/deflate and signed or unsigned descriptors preserve exact content',
    () {
      for (final method in [0, 8]) {
        for (final descriptor in [false, true]) {
          for (final signature in [false, true]) {
            final bytes = utf8.encode('Mầm: dữ liệu nguyên vẹn.');
            final a = CharacterZip.read(
              zip(
                [
                  Entry('assets/', [], method: 0, attributes: 0x41ed0010),
                  Entry('assets/name.txt', bytes, method: method),
                ],
                descriptor: descriptor,
                signature: signature,
              ),
            );
            expect(a.files['assets/name.txt'], bytes);
            expect(a.expandedBytes, bytes.length);
          }
        }
      }
    },
  );
  test(
    'rejects traversal, absolute paths, aliases and Windows device names',
    () {
      for (final name in [
        '../a.png',
        '/a.png',
        'C:/a.png',
        'a\\b.png',
        'a//b.png',
        'a/./b.png',
        'a/../b.png',
        'a/NUL.png',
        'COM1',
        'a/Lpt9.txt',
        'a./b.png',
        'a /b.png',
        'a/%2e%2e/b.png',
        'a/b/c/d/e.png',
        'ảnh.png',
      ]) {
        expect(
          () => CharacterZip.read(
            zip([
              Entry(name, [1]),
            ]),
          ),
          failure('unsafe_path'),
          reason: name,
        );
      }
    },
  );
  test('rejects case duplicates and file/directory prefix collisions in either order', () {
    for (final entries in [
      [
        Entry('a.png', [1]),
        Entry('A.PNG', [2]),
      ],
      [
        Entry('a', [1]),
        Entry('a/b.png', [2]),
      ],
      [
        Entry('a/b.png', [1]),
        Entry('A', [2]),
      ],
      [Entry('a/', [], method: 0), Entry('A/', [], method: 0)],
    ]) {
      expect(() => CharacterZip.read(zip(entries)), failure('unsafe_path'));
    }
  });
  test(
    'rejects links, special files and reparse attributes before decompression',
    () {
      for (final attrs in [
        0xa1ff0000,
        0x11a40000,
        0x8000 | 0x400,
        0x41ed0000,
      ]) {
        expect(
          () => CharacterZip.read(
            zip([
              Entry('asset.png', [1], attributes: attrs),
            ]),
          ),
          failure('unsafe_path'),
        );
      }
    },
  );
  test(
    'rejects encrypted/unknown methods, ZIP64 and malformed extra fields',
    () {
      for (final entry in [
        Entry('a.png', [1], flags: 1),
        Entry('a.png', [1], method: 99),
        Entry('a.png', [1], version: 45),
        Entry('a.png', [1], extra: [1, 0, 0, 0]),
        Entry('a.png', [1], extra: [2, 0, 9, 0, 1]),
      ]) {
        expect(() => CharacterZip.read(zip([entry])), failure());
      }
    },
  );
  test(
    'checks actual streamed output rather than trusting small declared sizes',
    () {
      final bomb = Uint8List(1024 * 1024);
      expect(
        () => CharacterZip.read(zip([Entry('a.png', bomb, size: 64)])),
        failure('quota'),
      );
      expect(
        () => CharacterZip.read(zip([Entry('a.png', bomb)])),
        failure('quota'),
      );
    },
  );
  test('checks archive, per-file, entry count and total declared budgets before inflate', () {
    expect(
      () => CharacterZip.read(Uint8List(CharacterZip.maxArchiveBytes + 1)),
      failure('quota'),
    );
    expect(
      () => CharacterZip.read(
        zip([
          Entry('a.png', [1], size: CharacterZip.maxFileBytes + 1),
        ]),
      ),
      failure('quota'),
    );
    expect(
      () => CharacterZip.read(
        zip(List.generate(65, (i) => Entry('a$i.png', [1]))),
      ),
      failure('quota'),
    );
    final random = Random(17),
        noise = List.generate(50000, (_) => random.nextInt(256));
    expect(
      () => CharacterZip.read(
        zip(
          List.generate(
            5,
            (i) => Entry('a$i.png', noise, size: 7 * 1024 * 1024),
          ),
        ),
      ),
      failure('quota'),
    );
  });
  test(
    'rejects CRC, size, local-name mismatch, truncated and overlapping records',
    () {
      for (final bytes in [
        zip([
          Entry('a.png', [1, 2], crc: 0),
        ]),
        zip([
          Entry('a.png', [1], size: 2),
        ]),
        zip([
          Entry('a.png', [1], localName: 'b.png'),
        ]),
        zip([
          Entry('a.png', [1]),
          Entry('b.png', [2], localOffset: 0),
        ]),
        zip(
          [
            Entry('a.png', [1]),
          ],
          prefix: [77, 90],
        ),
        Uint8List.fromList([
          ...zip([
            Entry('a.png', [1]),
          ]),
          1,
        ]),
        zip([
          Entry('a.png', [1]),
        ]).sublist(0, 20),
      ]) {
        expect(() => CharacterZip.read(bytes), failure());
      }
    },
  );
}
