import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';
import 'package:daymind_smart/features/companion/data/character_preparer.dart';
import 'package:daymind_smart/features/companion/presentation/character_animation.dart';
import 'package:daymind_smart/platform/floating_companion.dart';

import 'animation_fixture.dart';

Future<void> closeProbeDialog(
  WidgetTester tester,
  DialogRoute<void> route,
) async {
  var removed = false;
  final completed = route.completed.then<void>((_) {
    removed = true;
  });
  route.navigator!.pop();
  // Navigator's popped future completes before the exit transition and overlay
  // removal. Live native frames must reach completed before checking disposal.
  for (var i = 0; i < 60 && !removed; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    removed,
    isTrue,
    reason: 'Probe dialog overlay did not finish removal.',
  );
  await completed;
  await tester.pump();
}

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
    final route = DialogRoute<void>(
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
    unawaited(Navigator.of(page, rootNavigator: true).push(route));
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
    await closeProbeDialog(tester, route);
    await c.updateCompanionLayout((s) => s.copy(lowResource: true));
    await tester.pump(const Duration(milliseconds: 200));
    expect(framePaints, findsNothing);
    debugPrint(
      'ANIMATION_RESOURCE_POC: ${jsonEncode({'platform': Platform.operatingSystem, 'frames': 3, 'atlasWidth': 384, 'atlasHeight': 128, 'observedFrames': positions.length, 'observationMs': watch.elapsedMilliseconds, 'rssBefore': rssBefore, 'rssSamplePeak': peakRss, 'rssAfterPause': ProcessInfo.currentRss, 'imageCacheBytes': PaintingBinding.instance.imageCache.currentSizeBytes})}',
    );
    final maximum = await maximumAtlasProbe(tester, c, page, folder);
    if (Platform.isWindows) {
      await floatingCompanionProbe(tester, c, maximum);
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

Future<PreparedCharacterAnimation> maximumAtlasProbe(
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
      final route = DialogRoute<void>(
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
      unawaited(Navigator.of(page, rootNavigator: true).push(route));
      for (var i = 0; i < 60 && frames.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(frames, findsOneWidget);
      final paint =
          tester.widget<CustomPaint>(frames).painter! as CharacterFramePainter;
      expect((paint.atlas.width, paint.atlas.height), (2048, 1024));
      await tester.pump(const Duration(milliseconds: 100));
      peak = peak < ProcessInfo.currentRss ? ProcessInfo.currentRss : peak;
      await closeProbeDialog(tester, route);
      expect(frames, findsNothing);
      // clone() explicitly rejects disposed handles in every build mode;
      // debugDisposed is unavailable in AOT profile.
      expect(() {
        final unexpected = paint.atlas.clone();
        unexpected.dispose(); // Avoid leaking a handle when the gate fails.
      }, throwsStateError);
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
  return prepared.animation!;
}

Future<void> floatingCompanionProbe(
  WidgetTester tester,
  WorkspaceController c,
  PreparedCharacterAnimation maximum,
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

  // The component uses the same C++ class and real Win32/GDI+ messages, with
  // controlled notification-state inputs. The app always keeps the real reader.
  final exe = Directory(Platform.resolvedExecutable).parent;
  final component = p.join(
    exe.parent.parent.path,
    'companion-tests',
    p.basename(exe.path),
    'daymind_companion_component_probe.exe',
  );
  final probe = p.join(
    exe.parent.parent.path,
    'companion-tests',
    p.basename(exe.path),
    'daymind_companion_window_probe.exe',
  );
  expect(
    File(component).existsSync(),
    isTrue,
    reason: 'Native component gate must be built.',
  );
  expect(
    File(probe).existsSync(),
    isTrue,
    reason: 'Native app window gate must be built.',
  );
  final folder = await Directory.systemTemp.createTemp(
    'daymind-gdi-component-',
  );
  try {
    final atlas = await File(p.join(folder.path, 'fixture.png'))
        .writeAsBytes(maximum.atlasBytes);
    final result = await Process.run(component, [
      atlas.path,
      '$pid',
    ], workingDirectory: exe.path);
    debugPrint('${result.stdout}'.trim());
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect('${result.stdout}', contains('COMPANION_COMPONENT:'));
    expect('${result.stdout}', contains('COMPONENT_FLOATING_RESOURCE_POC:'));
  } finally {
    await folder.delete(recursive: true);
  }
  bool availableOrBlocked(Map<dynamic, dynamic> s) =>
      s['exists'] == true && (s['visible'] == true || s['reason'] == 'focus');
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
    final started = await until(availableOrBlocked);
    expect(
      started['atlasWidth'],
      128,
    ); // low-resource preview has no animation atlas.
    final osBlocked = started['visible'] != true;
    if (osBlocked) {
      expect([1, 2, 3, 4, 6], contains(started['notificationState']));
      expect(started['reason'], 'focus');
      expect(started['surfaceBytes'], 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect((await state())['renders'], started['renders']);
      debugPrint(
        'OS_FOCUS_BLOCKED_POC: actual app honors Windows state ${started['notificationState']}; surface released and no frames rendered.',
      );
    }
    final result = await Process.run(probe, [
      '$pid',
      if (osBlocked) 'policy-hidden',
    ]);
    debugPrint('${result.stdout}'.trim());
    expect(result.exitCode, 0, reason: '${result.stderr}');
    await c.updateFloating((s) => s.copy(clickThrough: true));
    await until((s) => s['clickThrough'] == true);
    final click = await Process.run(probe, [
      '$pid',
      'click-through',
      if (osBlocked) 'policy-hidden',
    ]);
    debugPrint('${click.stdout}'.trim());
    expect(click.exitCode, 0, reason: '${click.stderr}');
    await FloatingCompanionService.channel.invokeMethod<void>('recover');
    await until((s) => s['clickThrough'] == false);
    await c.updateCompanionLayout((s) => s.copy(lowResource: false));
    await until((s) => availableOrBlocked(s) && s['atlasWidth'] == 384);
    final animBefore = await state(), observed = <int>{};
    final watch = Stopwatch()..start();
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      observed.add((await state())['frame'] as int);
    }
    final animAfter = await state();
    if (osBlocked) {
      expect(animAfter['visible'], isFalse);
      expect(animAfter['renders'], animBefore['renders']);
      expect(animAfter['surfaceBytes'], 0);
    } else {
      expect(observed.length, greaterThanOrEqualTo(2));
    }
    expect(animAfter['atlasWidth'], 384);
    expect(
      (animAfter['renders'] as int) - (animBefore['renders'] as int),
      lessThanOrEqualTo((watch.elapsedMilliseconds / 84).ceil() + 3),
    );
    debugPrint(
      'FLOATING_ANIMATION_POC: ${jsonEncode({'osBlocked': osBlocked, 'observedFrames': observed.length, 'elapsedMs': watch.elapsedMilliseconds, 'renders': (animAfter['renders'] as int) - (animBefore['renders'] as int), 'cpuMs': (animAfter['cpuMs'] as int) - (animBefore['cpuMs'] as int)})}',
    );
    await c.window!.hide();
    await tester.pump(const Duration(milliseconds: 600));
    expect((await state())['exists'], isTrue);
    expect((await state())['visible'], !osBlocked);
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
    await until(availableOrBlocked);
    final baseline = await state();
    for (var i = 0; i < 20; i++) {
      await c.updateFloating((s) => s.copy(enabled: false));
      await until((s) => s['exists'] == false);
      await c.updateFloating((s) => s.copy(enabled: true));
      await until(availableOrBlocked);
    }
    final after = await state();
    expect(
      after['gdiObjects'] as int,
      lessThanOrEqualTo((baseline['gdiObjects'] as int) + 8),
    );
    expect(after['surfaceBytes'] as int, lessThanOrEqualTo(2048 * 2048 * 4));
    debugPrint(
      'FLOATING_RESOURCE_POC: ${jsonEncode({'osBlocked': osBlocked, 'cycles': 20, 'gdiBefore': baseline['gdiObjects'], 'gdiAfter': after['gdiObjects'], 'surfaceBytes': after['surfaceBytes'], 'cpuMs': (after['cpuMs'] as int) - (baseline['cpuMs'] as int), 'rssAfterCycles': ProcessInfo.currentRss})}',
    );
  } finally {
    await c.reminders!.configure(settings);
    await c.updateFloating((_) => originalFloating.copy(enabled: false));
    await until((s) => s['exists'] == false);
    await c.window!.show();
  }
}
