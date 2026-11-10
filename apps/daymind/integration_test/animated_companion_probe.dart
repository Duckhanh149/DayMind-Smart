import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';
import 'package:daymind_smart/features/companion/data/character_preparer.dart';
import 'package:daymind_smart/features/companion/presentation/character_animation.dart';
import 'package:daymind_smart/platform/floating_companion.dart';

import 'animation_fixture.dart';

Future<void> animatedCompanionProbe(
  WidgetTester tester,
  WorkspaceController c,
  BuildContext page,
) async {
  final folder = await Directory.systemTemp.createTemp(
    'daymind-animation-native-',
  );
  final source = await File(p.join(folder.path, 'probe.gif'))
      .writeAsBytes(base64Decode(companionGifFixture));
  final rssBefore = ProcessInfo.currentRss;
  var peakRss = rssBefore;
  final prepared = await c.importer.prepareCharacter(source, 'probe.gif');
  final name = await c.importer.installPrepared(
    prepared,
    rightsConfirmed: true,
  );
  await c.configure((prefs) => prefs.copyWith(assetName: name));
  await c.mapExpression(CompanionExpression.neutral, null);
  await c.updateCompanionLayout((s) => s.copy(lowResource: false));
  final framePaints = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is CharacterFramePainter,
  );
  try {
    // Exercise the real native renderer independently of emulator accessibility
    // settings. Product portraits still honor the user's reduced-motion setting.
    final dialog = showDialog<void>(
      context: page,
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: false, accessibleNavigation: false),
        child: AlertDialog(
          content: SizedBox(
            width: 128,
            height: 128,
            child: CharacterAnimationView(
              importer: c.importer,
              name: name,
              expression: CompanionExpression.neutral,
              fallback: const Text('Đang nạp hoạt ảnh'),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 60 && framePaints.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(framePaints, findsOneWidget);
    final first =
        tester.widget<CustomPaint>(framePaints).painter!
            as CharacterFramePainter;
    expect((first.atlas.width, first.atlas.height), (384, 128));
    final positions = <int>{};
    final watch = Stopwatch()..start();
    for (var i = 0; i < 36; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final paint =
          tester.widget<CustomPaint>(framePaints).painter!
              as CharacterFramePainter;
      expect(paint.atlas, same(first.atlas));
      positions.add(paint.frame.x);
      peakRss = peakRss < ProcessInfo.currentRss
          ? ProcessInfo.currentRss
          : peakRss;
    }
    expect(positions.length, greaterThanOrEqualTo(2));
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pump(const Duration(milliseconds: 400));
    await dialog;
    await c.updateCompanionLayout((s) => s.copy(lowResource: true));
    await tester.pump(const Duration(milliseconds: 200));
    expect(framePaints, findsNothing);
    debugPrint(
      'ANIMATION_RESOURCE_POC: ${jsonEncode({'platform': Platform.operatingSystem, 'frames': 3, 'atlasWidth': 384, 'atlasHeight': 128, 'observedFrames': positions.length, 'observationMs': watch.elapsedMilliseconds, 'rssBefore': rssBefore, 'rssSamplePeak': peakRss, 'rssAfterPause': ProcessInfo.currentRss, 'imageCacheBytes': PaintingBinding.instance.imageCache.currentSizeBytes})}',
    );
    await maximumAtlasProbe(tester, c, page, folder);
    if (Platform.isWindows) {
      await floatingCompanionProbe(tester, c, prepared.animation!);
    }
  } finally {
    await c.updateFloating((s) => s.copy(enabled: false));
    await c.configure((prefs) => prefs.copyWith(resetAsset: true));
    await c.updateCompanionLayout((s) => s.copy(lowResource: false));
    await c.removeCompanionAsset(name);
    await folder.delete(recursive: true);
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> maximumAtlasProbe(
  WidgetTester tester,
  WorkspaceController c,
  BuildContext page,
  Directory folder,
) async {
  final source = await File(p.join(folder.path, 'max.gif'))
      .writeAsBytes(base64Decode(companionMaxGifFixture));
  final before = ProcessInfo.currentRss;
  var peak = before;
  final prepared = await c.importer.prepareCharacter(source, 'max.gif');
  final meta = prepared.animation!.metadata;
  expect((meta.frames.length, meta.width, meta.height), (120, 2048, 1024));
  final name = await c.importer.installPrepared(
    prepared,
    rightsConfirmed: true,
  );
  final frames = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is CharacterFramePainter,
  );
  try {
    for (var cycle = 0; cycle < 6; cycle++) {
      final dialog = showDialog<void>(
        context: page,
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: false, accessibleNavigation: false),
          child: AlertDialog(
            content: SizedBox(
              width: 128,
              height: 128,
              child: CharacterAnimationView(
                importer: c.importer,
                name: name,
                expression: CompanionExpression.neutral,
                fallback: const Text('Nạp atlas tối đa'),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 60 && frames.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(frames, findsOneWidget);
      final paint =
          tester.widget<CustomPaint>(frames).painter! as CharacterFramePainter;
      expect((paint.atlas.width, paint.atlas.height), (2048, 1024));
      await tester.pump(const Duration(milliseconds: 100));
      peak = peak < ProcessInfo.currentRss ? ProcessInfo.currentRss : peak;
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pump(const Duration(milliseconds: 400));
      await dialog;
      expect(frames, findsNothing);
      expect(paint.atlas.debugDisposed, isTrue);
    }
    expect(
      peak - before,
      lessThan(256 * 1024 * 1024),
      reason: 'Maximum-atlas debug probe exceeded the extra-RSS guard.',
    );
    debugPrint(
      'MAX_ATLAS_RESOURCE_POC: ${jsonEncode({'platform': Platform.operatingSystem, 'frames': 120, 'cycles': 6, 'atlasWidth': 2048, 'atlasHeight': 1024, 'atlasRgbaBytes': 2048 * 1024 * 4, 'rssBefore': before, 'rssSamplePeak': peak, 'rssAfterPause': ProcessInfo.currentRss, 'allTextureHandlesDisposed': true})}',
    );
  } finally {
    await c.removeCompanionAsset(name);
  }
}

Future<void> floatingCompanionProbe(
  WidgetTester tester,
  WorkspaceController c,
  PreparedCharacterAnimation animation,
) async {
  Future<Map<dynamic, dynamic>> state() async => (await FloatingCompanionService
      .channel
      .invokeMapMethod<dynamic, dynamic>('state'))!;
  Future<Map<dynamic, dynamic>> until(
    bool Function(Map<dynamic, dynamic>) predicate,
  ) async {
    var current = await state();
    for (var i = 0; i < 80 && !predicate(current); i++) {
      await tester.pump(const Duration(milliseconds: 100));
      current = await state();
    }
    expect(
      predicate(current),
      isTrue,
      reason: 'Native floating state: $current',
    );
    return current;
  }

  final settings = c.reminders!.preferences.toJson();
  final originalFloating = c.floatingSettings;
  try {
    await c.reminders!.configure({'quietEnabled': false});
    await c.updateFloating(
      (s) => s.copy(
        enabled: true,
        topmost: false,
        clickThrough: false,
        resetPosition: true,
        size: 112,
      ),
    );
    final started = await until(
      (s) => s['exists'] == true && s['visible'] == true,
    );
    expect(
      started['atlasWidth'],
      128,
    ); // low-resource preview has no animation atlas.
    final exe = Directory(Platform.resolvedExecutable).parent;
    final probe = p.join(
      exe.parent.parent.path,
      'companion-tests',
      p.basename(exe.path),
      'daymind_companion_window_probe.exe',
    );
    expect(
      File(probe).existsSync(),
      isTrue,
      reason: 'Native gate probe must be built, never skipped.',
    );
    final result = await Process.run(probe, ['$pid']);
    debugPrint('${result.stdout}'.trim());
    expect(result.exitCode, 0, reason: '${result.stderr}');
    await c.updateFloating((s) => s.copy(clickThrough: true));
    await until((s) => s['clickThrough'] == true);
    final click = await Process.run(probe, ['$pid', 'click-through']);
    debugPrint('${click.stdout}'.trim());
    expect(click.exitCode, 0, reason: '${click.stderr}');
    await FloatingCompanionService.channel.invokeMethod<void>('recover');
    await until((s) => s['clickThrough'] == false);
    final m = animation.metadata;
    await FloatingCompanionService.channel.invokeMethod<void>('configure', {
      ...c.floatingSettings.toJson(),
      'quiet': false,
      'lowResource': false,
      'artKey': 'native-animation-probe',
      'expression': 'neutral',
      'image': animation.atlasBytes,
      'frames': m.frames.map((f) => f.toJson()).toList(),
      'sequence': [0, 1, 2],
      'loop': true,
    });
    final animBefore = await state(), observed = <int>{};
    final watch = Stopwatch()..start();
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      observed.add((await state())['frame'] as int);
    }
    final animAfter = await state();
    expect(observed.length, greaterThanOrEqualTo(2));
    expect(animAfter['atlasWidth'], 384);
    expect(
      (animAfter['renders'] as int) - (animBefore['renders'] as int),
      lessThanOrEqualTo((watch.elapsedMilliseconds / 84).ceil() + 3),
    );
    debugPrint(
      'FLOATING_ANIMATION_POC: ${jsonEncode({'observedFrames': observed.length, 'elapsedMs': watch.elapsedMilliseconds, 'renders': (animAfter['renders'] as int) - (animBefore['renders'] as int), 'cpuMs': (animAfter['cpuMs'] as int) - (animBefore['cpuMs'] as int)})}',
    );
    await c.window!.hide();
    await tester.pump(const Duration(milliseconds: 600));
    expect((await state())['exists'], isTrue);
    expect((await state())['visible'], isTrue);
    await c.window!.show();
    final minute = c.now().hour * 60 + c.now().minute;
    await c.reminders!.configure({
      'quietEnabled': true,
      'quietStart': (minute + 1439) % 1440,
      'quietEnd': (minute + 2) % 1440,
    });
    await until((s) => s['reason'] == 'quiet' && s['visible'] == false);
    final hidden = await state();
    await tester.pump(const Duration(milliseconds: 500));
    expect((await state())['renders'], hidden['renders']);
    expect(hidden['surfaceBytes'], 0);
    await c.reminders!.configure({'quietEnabled': false});
    await until((s) => s['visible'] == true);
    final baseline = await state();
    for (var i = 0; i < 20; i++) {
      await c.updateFloating((s) => s.copy(enabled: false));
      await until((s) => s['exists'] == false);
      await c.updateFloating((s) => s.copy(enabled: true));
      await until((s) => s['exists'] == true && s['visible'] == true);
    }
    final after = await state();
    expect(
      after['gdiObjects'] as int,
      lessThanOrEqualTo((baseline['gdiObjects'] as int) + 8),
    );
    expect(after['surfaceBytes'] as int, lessThanOrEqualTo(2048 * 2048 * 4));
    debugPrint(
      'FLOATING_RESOURCE_POC: ${jsonEncode({'cycles': 20, 'gdiBefore': baseline['gdiObjects'], 'gdiAfter': after['gdiObjects'], 'surfaceBytes': after['surfaceBytes'], 'cpuMs': (after['cpuMs'] as int) - (baseline['cpuMs'] as int), 'rssAfterCycles': ProcessInfo.currentRss})}',
    );
  } finally {
    await c.reminders!.configure(settings);
    await c.updateFloating((_) => originalFloating.copy(enabled: false));
    await until((s) => s['exists'] == false);
    await c.window!.show();
  }
}
