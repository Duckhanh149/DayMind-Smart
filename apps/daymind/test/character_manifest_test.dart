import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/features/companion/data/safe_zip.dart';
import 'package:daymind_smart/features/companion/domain/character_package.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';

void main() {
  late Map<String, Uint8List> files;
  late Map<String, dynamic> valid;
  setUp(() async {
    files = CharacterZip.read(
      await File('test/fixtures/valid_character.zip').readAsBytes(),
    ).files;
    valid = characterJson(files['manifest.json']!);
  });
  test('versioned sprite manifest checks every source file and round-trips independent expression/motion maps', () {
    final manifest = CharacterManifest.fromJson(valid);
    manifest.validateFiles(files);
    expect(manifest.kind, CharacterPackageKind.sprite);
    expect(manifest.expressions[CompanionExpression.neutral], 'idle');
    expect(manifest.motions['idle']!.frames, [0]);
    expect(manifest.provenance.author, 'DayMind');
    manifest.frames.single.validateBounds(8, 8);
    expect(
      CharacterManifest.fromJson(manifest.toJson()).toJson(),
      manifest.toJson(),
    );
    expect(
      () => manifest.motions['idle']!.frames.add(1),
      throwsUnsupportedError,
    );
    expect(() => manifest.checksums['bad'] = 'changed', throwsUnsupportedError);
  });
  test('unknown code/model/network fields, versions and unsafe paths cannot enter the manifest', () {
    for (final overrides in [
      {'script': 'run.exe'},
      {'model': 'avatar.moc3'},
      {'downloadUrl': 'https://example.invalid/code'},
      {'version': 2},
      {'kind': 'live2d'},
      {'image': '../sheet.png'},
      {'image': 'https://example.invalid/a.png'},
      {'image': 'C:/sheet.png'},
      {
        'provenance': {'license': 'Allowed', 'token': 'private'},
      },
    ]) {
      expect(
        () => CharacterManifest.fromJson({...valid, ...overrides}),
        throwsA(isA<CharacterPackageFailure>()),
      );
    }
  });
  test('unreferenced content, mismatched SHA256 and invalid license files are rejected', () {
    final manifest = CharacterManifest.fromJson(valid);
    expect(
      () => manifest.validateFiles({...files, 'run.exe': Uint8List(1)}),
      throwsA(isA<CharacterPackageFailure>()),
    );
    expect(
      () => manifest.validateFiles({...files, manifest.image: Uint8List(8)}),
      throwsA(isA<CharacterPackageFailure>()),
    );
    final license = Uint8List.fromList([255]);
    final withLicense = CharacterManifest.fromJson({
      ...valid,
      'licenseFile': 'LICENSE.txt',
      'checksums': {
        ...valid['checksums'] as Map,
        'LICENSE.txt': sha256.convert(license).toString(),
      },
    });
    expect(
      () => withLicense.validateFiles({...files, 'LICENSE.txt': license}),
      throwsA(isA<CharacterPackageFailure>()),
    );
  });
  test('sprite bounds, frame types, motion references and cumulative duration stay bounded', () {
    for (final overrides in [
      {
        'frames': [
          {'x': -1, 'y': 0, 'width': 8, 'height': 8, 'durationMs': 125},
        ],
      },
      {
        'frames': [
          {'x': 0, 'y': 0, 'width': 8.5, 'height': 8, 'durationMs': 125},
        ],
      },
      {'frames': List.filled(121, (valid['frames'] as List).first)},
      {
        'motions': {
          'idle': {
            'frames': [1],
          },
        },
      },
      {
        'expressions': {'unknown': 'idle'},
      },
      {
        'expressions': {'happy': 'missing'},
      },
    ]) {
      expect(
        () => CharacterManifest.fromJson({...valid, ...overrides}),
        throwsA(isA<CharacterPackageFailure>()),
      );
    }
    final frame = CharacterManifest.fromJson(valid).frames.single;
    expect(
      () => frame.validateBounds(7, 8),
      throwsA(isA<CharacterPackageFailure>()),
    );
    final manifest = CharacterManifest.fromJson({
      ...valid,
      'motions': {
        'idle': {'frames': List.filled(120, 0)},
      },
    });
    expect(
      () => manifest.validateFrameCount(1, durations: [1000]),
      throwsA(isA<CharacterPackageFailure>()),
    );
    expect(
      () => manifest.validateFrameCount(1, durations: []),
      throwsA(isA<CharacterPackageFailure>()),
    );
  });
  test('JSON depth, size, malformed UTF8 and trailing syntax are rejected before model parsing', () {
    for (final bytes in [
      Uint8List(65537),
      Uint8List.fromList([255]),
      Uint8List.fromList(utf8.encode('${'[' * 13}0${']' * 13}')),
      Uint8List.fromList(utf8.encode('{"name":"unterminated}')),
    ]) {
      expect(
        () => characterJson(bytes),
        throwsA(isA<CharacterPackageFailure>()),
      );
    }
  });
}
