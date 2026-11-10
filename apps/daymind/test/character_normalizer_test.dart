import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/features/companion/data/character_preparer.dart';
import 'package:daymind_smart/features/companion/data/image_preflight.dart';
import 'package:daymind_smart/features/companion/domain/character_package.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';

import '../integration_test/animation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('sprite crop coordinates preserve separate panels, transparent letterboxing, clips and license text', () async {
    final plan = await CharacterBlueprint.inspect(
      await File('test/fixtures/three_sprite_frames.zip').readAsBytes(),
      'zip',
      'Sprite',
    );
    final result = await CharacterNormalizer.build(plan);
    expect((result.metadata.width, result.metadata.height), (384, 128));
    expect(result.metadata.motions['cheer']!.frames, [2, 0]);
    expect(result.metadata.motions['cheer']!.loop, isFalse);
    expect(result.metadata.expressions[CompanionExpression.happy], 'cheer');
    expect(
      utf8.decode(result.licenseBytes!),
      contains('no third-party character'),
    );
    final codec = await ui.instantiateImageCodec(result.atlasBytes);
    final image = (await codec.getNextFrame()).image;
    try {
      final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      const colors = [
        [140, 170, 80, 255],
        [80, 120, 180, 255],
        [220, 150, 130, 255],
      ];
      for (var i = 0; i < 3; i++) {
        final center = (64 * image.width + i * 128 + 64) * 4;
        expect(rgba.sublist(center, center + 4), colors[i]);
        final margin = (64 * image.width + i * 128 + 5) * 4;
        expect(
          rgba[margin + 3],
          0,
          reason: 'Portrait proportions must be preserved.',
        );
      }
    } finally {
      image.dispose();
      codec.dispose();
    }
  });
  test('120 original frames normalize within the maximum atlas and preserve the final composited pixels', () async {
    final plan = await CharacterBlueprint.inspect(
      base64Decode(companionMaxGifFixture),
      'gif',
      'Atlas tối đa',
    );
    final result = await CharacterNormalizer.build(plan);
    expect(
      (
        result.metadata.frames.length,
        result.metadata.width,
        result.metadata.height,
      ),
      (120, 2048, 1024),
    );
    final codec = await ui.instantiateImageCodec(result.atlasBytes);
    final image = (await codec.getNextFrame()).image;
    try {
      final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      for (final i in [0, 59, 119]) {
        final frame = result.metadata.frames[i];
        final pixel = ((frame.y + 64) * image.width + frame.x + 64) * 4;
        expect(rgba.sublist(pixel, pixel + 4), [
          (i * 53) % 256,
          (i * 79 + 40) % 256,
          (i * 113 + 80) % 256,
          255,
        ]);
      }
    } finally {
      image.dispose();
      codec.dispose();
    }
  });
  test('ZIP inspection runs in an isolate and normalizes a sprite without exposing archive paths', () async {
    final source = await File('test/fixtures/valid_character.zip')
        .readAsBytes();
    final plan = await CharacterBlueprint.inspect(source, 'zip', 'Ảnh nhập');
    final result = await CharacterNormalizer.build(plan);
    final m = result.metadata;
    expect(m.name, 'Mầm thử nghiệm');
    expect(m.sourceHash, sha256.convert(source).toString());
    expect((m.width, m.height, m.frames.length), (128, 128, 1));
    expect(m.atlasHash, sha256.convert(result.atlasBytes).toString());
    expect(m.previewHash, sha256.convert(result.previewBytes).toString());
    expect(CharacterRenderData.fromJson(m.toJson()).toJson(), m.toJson());
    expect(m.toJson().keys, isNot(contains('image')));
    expect(CharacterImageProbe.inspect(result.previewBytes).width, 128);
  });
  test('GIF and WebP become bounded tile atlases with exact composited frame colors and capped timing', () async {
    for (final format in ['gif', 'webp']) {
      final bytes = await File('test/fixtures/three_frames.$format')
          .readAsBytes();
      final plan = await CharacterBlueprint.inspect(bytes, format, 'Mầm');
      final result = await CharacterNormalizer.build(plan);
      expect((result.metadata.width, result.metadata.height), (384, 128));
      expect(
        result.metadata.frames.map((f) => f.durationMs),
        format == 'gif' ? [125, 84, 200] : [84, 150, 200],
      );
      final codec = await ui.instantiateImageCodec(result.atlasBytes);
      final image = (await codec.getNextFrame()).image;
      try {
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        const colors = [
          [140, 170, 80],
          [80, 120, 180],
          [220, 150, 130],
        ];
        for (var frame = 0; frame < 3; frame++) {
          final pixel = (64 * image.width + frame * 128 + 64) * 4;
          expect(rgba.sublist(pixel, pixel + 4), [...colors[frame], 255]);
        }
      } finally {
        image.dispose();
        codec.dispose();
      }
    }
  });
  test('cancellation before and during decoding discards work and allows a fresh preparation', () async {
    final bytes = await File('test/fixtures/three_frames.gif').readAsBytes();
    final plan = await CharacterBlueprint.inspect(bytes, 'gif', 'Mầm');
    await expectLater(
      CharacterNormalizer.build(plan, cancelled: () => true),
      throwsA(isA<CharacterImportCancelled>()),
    );
    var cancel = false;
    await expectLater(
      CharacterNormalizer.build(
        plan,
        cancelled: () => cancel,
        progress: (done, _) {
          if (done == 1) cancel = true;
        },
      ),
      throwsA(isA<CharacterImportCancelled>()),
    );
    final next = await CharacterNormalizer.build(plan);
    expect(next.metadata.frames, hasLength(3));
    expect(sha256.convert(bytes).toString(), next.metadata.sourceHash);
  });
  test('installed render metadata rejects altered grids, timings, hashes and external paths', () async {
    final plan = await CharacterBlueprint.inspect(
      await File('test/fixtures/three_frames.gif').readAsBytes(),
      'gif',
      'Mầm',
    );
    final m = (await CharacterNormalizer.build(plan)).metadata.toJson();
    for (final change in [
      {'width': 4096},
      {'atlasHash': 'not-a-hash'},
      {'path': '/outside.png'},
      {
        'frames': [
          for (final f in m['frames'] as List) {...f as Map, 'durationMs': 1},
        ],
      },
      {
        'motions': {
          'idle': {
            'frames': [119],
            'loop': true,
          },
        },
      },
    ]) {
      expect(
        () => CharacterRenderData.fromJson({...m, ...change}),
        throwsA(isA<CharacterPackageFailure>()),
      );
    }
    expect(
      () => CharacterRenderData.fromJson({...m, 'frames': Uint8List(0)}),
      throwsA(isA<CharacterPackageFailure>()),
    );
  });
}
