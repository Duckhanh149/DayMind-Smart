import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:daymind_smart/app/workspace_host.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';
import 'package:daymind_smart/features/companion/presentation/character_animation.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/backup/data/backup_codec.dart';

import 'animation_fixture.dart';
import 'support/resource_sampler.dart';

Future<void> resourceProbe(WidgetTester tester, WorkspaceHost host) async {
  if (!const bool.fromEnvironment('RUN_RESOURCE_SOAK')) return;
  const seconds = int.fromEnvironment(
    'DAYMIND_RESOURCE_SOAK_SECONDS',
    defaultValue: 120,
  );
  expect(seconds, inInclusiveRange(120, 600));
  final c = host.controller!, original = c.preferences;
  final binding = tester.binding as LiveTestWidgetsFlutterBinding;
  final previousFramePolicy = binding.framePolicy;
  // Profile actual continuous animation, not one rendered frame per pump.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final previousNames = c.importer.installed().toSet();
  final folder = await Directory.systemTemp.createTemp(
    'daymind-resource-native-',
  );
  final metrics = <String, Map<String, Object?>>{};
  ResourceSampler? active;
  final timer = Timer.periodic(
    const Duration(milliseconds: 250),
    (_) => active?.sample(),
  );
  Future<T> measure<T>(String stage, Future<T> Function() body) async {
    final sample = ResourceSampler();
    active = sample;
    try {
      return await body();
    } finally {
      metrics[stage] = sample.finish();
      expect(
        metrics[stage]!['cpuSupported'],
        isTrue,
        reason:
            'Native process CPU accounting must be available on the target OS.',
      );
      active = null;
    }
  }

  final fixtureIds = <String>[];
  DialogRoute<void>? route;
  try {
    final gif = await File('${folder.path}/animation.gif')
        .writeAsBytes(base64Decode(companionMaxGifFixture));
    final name = await measure('animatedImport', () async {
      final prepared = await c.importer.prepareCharacter(gif, 'animation.gif');
      return c.importer.installPrepared(prepared, rightsConfirmed: true);
    });
    await c.configure((p) => p.copyWith(assetName: name));
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    route = DialogRoute<void>(
      context: navigator.context,
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: false, accessibleNavigation: false),
        child: Dialog(
          child: SizedBox(
            width: 256,
            height: 256,
            child: CharacterAnimationView(
              importer: c.importer,
              name: name,
              expression: CompanionExpression.neutral,
              fallback: const Icon(Icons.person),
            ),
          ),
        ),
      ),
    );
    unawaited(navigator.push(route));
    await tester.pump(const Duration(milliseconds: 400));
    final observedFrames = <int>{};
    final framePaints = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CharacterFramePainter,
    );
    await measure('companionAndSyncSoak', () async {
      final watch = Stopwatch()..start();
      var nextSync = 0;
      while (watch.elapsed.inSeconds < seconds) {
        if (watch.elapsed.inSeconds >= nextSync) {
          fixtureIds.add(
            await c.save(TaskDraft(title: 'Synthetic resource sync fixture')),
          );
          await host.sync!.sync();
          nextSync += 20;
        }
        await tester.pump(const Duration(seconds: 1));
        active?.sample();
        if (framePaints.evaluate().isNotEmpty) {
          final paint =
              tester.widget<CustomPaint>(framePaints.first).painter!
                  as CharacterFramePainter;
          observedFrames.add(paint.frame.x + paint.frame.y * 2048);
        }
      }
      expect(
        observedFrames.length,
        greaterThan(1),
        reason: 'The measured companion must actually animate.',
      );
      expect(watch.elapsed.inSeconds, greaterThanOrEqualTo(seconds));
    });
    navigator.pop();
    await tester.pump(const Duration(milliseconds: 400));
    route = null;
    await c.configure((_) => original);
    // Three real, distinct 12 MiB BMPs: >36 MiB of validated image sources.
    // No random/raw buffers masquerading as importable images.
    await measure('largeImageImport', () async {
      for (var n = 0; n < 3; n++) {
        const side = 2048, size = 54 + side * side * 3;
        final bytes = Uint8List(size)..fillRange(54, size, 80 + n * 30);
        final d = ByteData.sublistView(bytes);
        bytes[0] = 66;
        bytes[1] = 77;
        d.setUint32(2, size, Endian.little);
        d.setUint32(10, 54, Endian.little);
        d.setUint32(14, 40, Endian.little);
        d.setUint32(18, side, Endian.little);
        d.setUint32(22, side, Endian.little);
        d.setUint16(26, 1, Endian.little);
        d.setUint16(28, 24, Endian.little);
        await c.importer.installBytes(bytes, 'resource.bmp');
        active?.sample();
      }
    });
    final snapshot = await measure('largeBackupCapture', host.captureBackup);
    final sourceBytes = snapshot.assets.fold<int>(
      0,
      (n, a) => n + a.byteLength,
    );
    expect(sourceBytes, greaterThan(36 * 1024 * 1024));
    final secret = const Uuid().v4();
    final encrypted = await measure(
      'largeBackupEncrypt',
      () => BackupCodec.encrypt(snapshot, secret),
    );
    final decoded = await measure(
      'largeBackupDecrypt',
      () => BackupCodec.decrypt(encrypted, secret),
    );
    expect(
      decoded.assets.map((a) => a.name).toSet(),
      snapshot.assets.map((a) => a.name).toSet(),
    );
    expect(decoded.records.length, snapshot.records.length);
    // Real native restore/no-replay is separately covered by backupProbe.
    // Here measure the large validated snapshot/KDF/codec without duplicating
    // the account's recurrence and alarm fixtures before that correctness gate.
    for (final id in fixtureIds) {
      final task = c.tasks.where((t) => t.id == id).firstOrNull;
      if (task != null) await c.delete(task);
    }
    await host.sync!.sync();
    expect(host.sync!.pendingCount, 0);
    // Android log entries can truncate long lines; keep every metric decodable.
    for (final entry in metrics.entries) {
      debugPrint(
        'RESOURCE_STAGE_POC: ${jsonEncode({'stage': entry.key, ...entry.value})}',
      );
    }
    debugPrint(
      'RESOURCE_SOAK_POC: ${jsonEncode({'platform': Platform.operatingSystem, 'buildMode': kProfileMode ? 'profile' : 'debug', 'durationSeconds': seconds, 'frames': 120, 'observedFrames': observedFrames.length, 'sourceBytes': sourceBytes, 'cipherBytes': encrypted.length, 'syncWrites': fixtureIds.length, 'floatingStatus': c.floatingStatus == null ? 'notReported' : 'osPolicyReported', 'metricStages': metrics.keys.toList(), 'scope': 'native Flutter process; no private receiver process CPU/RSS or physical low-end certification'})}',
    );
  } finally {
    binding.framePolicy = previousFramePolicy;
    timer.cancel();
    if (route != null && route.isCurrent) {
      route.navigator?.pop();
      await tester.pump(const Duration(milliseconds: 400));
    }
    await c.configure((_) => original);
    for (final name
        in c.importer
            .installed()
            .where((n) => !previousNames.contains(n))
            .toList()) {
      await c.importer.remove(name);
    }
    await folder.delete(recursive: true);
  }
}
