import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'companion_fixtures.dart';
import 'animated_companion_probe.dart';
import 'account_artwork_probe.dart';
import 'backup_probe.dart';
import 'resource_probe.dart';
import 'windows_notification_probe.dart';
import 'android_sqlite_probe.dart';

import 'dart:io';
import 'dart:convert';

import 'package:go_router/go_router.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:daymind_smart/main.dart' as app;
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/recurrence/domain/recurrence.dart';
import 'package:daymind_smart/features/recurrence/application/recurrence_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/app/workspace_host.dart';
import 'package:daymind_smart/features/account_sync/domain/sync_record.dart';
import 'package:uuid/uuid.dart';
import 'package:daymind_smart/features/tasks/presentation/workspace_screen.dart';
import 'package:daymind_smart/platform/secure_session_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  debugPrint('NATIVE_INTEGRATION_STAGE: Dart entrypoint reached.');
  testWidgets('native startup and durable task creation', (tester) async {
    // FLUTTER_TEST otherwise makes defaultTargetPlatform Android on Windows,
    // causing the notification plugin to select the wrong platform adapter.
    if (kDebugMode) {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = Platform.isWindows
          ? TargetPlatform.windows
          : TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
    }
    debugPrint('NATIVE_INTEGRATION_STAGE: opening workspace.');
    await app.main();
    debugPrint('NATIVE_INTEGRATION_STAGE: workspace opened.');
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    final secure = NativeSessionStore();
    const probe = 'DayMind native credential probe · ă';
    await secure.set('test_probe', probe);
    expect(await secure.get('test_probe'), probe);
    await secure.set('test_probe', '$probe updated');
    expect(await secure.get('test_probe'), '$probe updated');
    await secure.remove('test_probe');
    expect(await secure.get('test_probe'), isNull);
    debugPrint(
      'SECURE_STORAGE_POC: native encrypted write/read/replace/delete passed.',
    );
    final scoped = NativeSessionStore(namespace: 'production.daymind-ci.');
    final legacySession = await secure.get('session');
    await scoped.set('session', probe);
    expect(await scoped.get('session'), probe);
    await scoped.remove('session');
    expect(await scoped.get('session'), isNull);
    expect(await secure.get('session'), legacySession);
    debugPrint(
      'SCOPED_SESSION_POC: native encrypted backend isolation passed.',
    );

    await tester.tap(find.byKey(const Key('add-task')));
    await tester.pumpAndSettle();
    final title = 'Native smoke ${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(find.byKey(const Key('task-title')), title);
    await tester.tap(find.byKey(const Key('save-task')));
    await tester.pumpAndSettle();
    // A settled frame queue does not imply that the SQLite worker committed
    // and the async editor callback popped its route, especially under AOT.
    final saved = Stopwatch()..start();
    while (find.byType(Dialog).evaluate().isNotEmpty &&
        saved.elapsed < const Duration(seconds: 10)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (find.byType(Dialog).evaluate().isNotEmpty) {
      final field = tester.widget<TextField>(
        find.byKey(const Key('task-title')),
      );
      debugPrint(
        'NATIVE_EDITOR_STATE: ${jsonEncode({'titleLength': field.controller?.text.length, 'savingIndicatorCount': find.byType(CircularProgressIndicator).evaluate().length, 'dialogStillOpen': true})}',
      );
    }
    expect(find.byType(Dialog), findsNothing);
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(WorkspaceScreen)),
    ).read(workspaceProvider);
    final reminders = controller.reminders;
    expect(reminders, isNotNull);
    debugPrint(
      'NOTIFICATION_POC: permission/initialization=${reminders!.granted}; closed-app adapter=${reminders.engine.scheduler.supportsClosedApp}',
    );
    if (reminders.granted) {
      await reminders.test();
    }
    if (Platform.isWindows) {
      final window = controller.window!;
      await window.refresh();
      expect(window.iconReady, isTrue, reason: window.error);
      await window.hide();
      await tester.pump(const Duration(milliseconds: 200));
      await window.refresh();
      expect(window.visible, isFalse);
      expect(window.trayEnabled, isTrue);
      await window.show();
      await tester.pump(const Duration(milliseconds: 200));
      await window.refresh();
      expect(window.visible, isTrue);
      debugPrint(
        'TRAY_POC: WM_CLOSE hides, process stays active, restore succeeds.',
      );
      await windowsNotificationProbe(tester, controller);
    }
    final now = controller.now();
    final recurring = await controller.save(
      TaskDraft(
        title: '$title recurring',
        scheduledStartAt: now.add(const Duration(hours: 1)),
        dueAt: now.add(const Duration(hours: 2)),
      ),
      repetition: RepeatChange(
        enabled: true,
        spec: RepeatSpec(
          frequency: RepeatFrequency.daily,
          firstDate: dateKey(
            tz.TZDateTime.from(
              now.add(const Duration(hours: 1)),
              zoneLocation(reminders.preferences.timezoneId),
            ),
          ),
          zone: reminders.preferences.timezoneId,
          count: 3,
        ),
      ),
    );
    var instances =
        controller.visibleTasks.where((t) => t.seriesId == recurring).toList()
          ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    expect(instances.length, 3);
    await controller.toggle(instances.first);
    instances =
        controller.visibleTasks.where((t) => t.seriesId == recurring).toList()
          ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    expect(instances.first.status, TaskStatus.completed);
    expect(
      controller.tasks.singleWhere((t) => t.id == recurring).status,
      TaskStatus.todo,
    );
    await controller.save(
      TaskDraft.fromJson({
        ...TaskDraft.fromTask(instances[1]).toJson(),
        'title': '$title future',
      }),
      existing: instances[1],
      scope: EditScope.future,
    );
    final changed = controller.visibleTasks
        .where((t) => t.seriesId == recurring && t.status == TaskStatus.todo)
        .toList();
    expect(changed.length, 2);
    expect(changed.every((t) => t.title == '$title future'), isTrue);
    await controller.delete(changed.first, scope: EditScope.all);
    debugPrint(
      'RECURRENCE_POC: real SQLite materialization, one completion and future edits preserve history.',
    );
    final tasks = await controller.repository.list();
    expect(
      tasks.any((task) => task.title == title && task.dueAt == null),
      true,
    );
    final task = tasks.firstWhere((task) => task.title == title);
    await controller.delete(task);
    await tester.pumpAndSettle();
    // Exercise real platform decoding/rendering, not a mocked image provider.
    final originalProfile = controller.companion;
    await controller.saveCompanion(
      originalProfile.copy(
        name: 'Mầm native',
        templates: {'gentle:taskCompleted': '{name}: xong {task}.'},
        expressions: {CompanionEvent.taskCompleted: CompanionExpression.happy},
      ),
    );
    await controller.configure((p) => p.copyWith(companionEnabled: true));
    await controller.updateCompanionLayout((v) => v.copy(lowResource: true));
    GoRouter.of(tester.element(find.byType(WorkspaceScreen))).go('/companion');
    await tester.pumpAndSettle();
    final rssBefore = ProcessInfo.currentRss;
    final timer = Stopwatch()..start();
    var peakRss = rssBefore, peakCache = 0;
    final images = <String>[];
    for (final fixture in companionPngFixtures) {
      images.add(
        await controller.importer.installBytes(
          base64Decode(fixture),
          'probe.png',
        ),
      );
      peakRss = peakRss < ProcessInfo.currentRss
          ? ProcessInfo.currentRss
          : peakRss;
    }
    final rssAfterImport = ProcessInfo.currentRss,
        importElapsedMs = timer.elapsedMilliseconds;
    timer.reset();
    for (var i = 0; i < 24; i++) {
      await controller.mapExpression(
        CompanionExpression.neutral,
        images[i % images.length],
      );
      await controller.configure(
        (p) => p.copyWith(assetName: images[i % images.length]),
      );
      await tester.pumpAndSettle();
      await precacheImage(
        ResizeImage(
          FileImage(
            (await controller.importer.renderFile(images[i % images.length]))!,
          ),
          width: 128,
          height: 128,
          policy: ResizeImagePolicy.fit,
          allowUpscaling: false,
        ),
        tester.element(find.byType(WorkspaceScreen)),
      );
      await tester.pumpAndSettle();
      final portrait = find.byKey(const Key('companion-portrait'));
      await tester.ensureVisible(portrait);
      await tester.pumpAndSettle();
      final displayed = find.descendant(
        of: portrait,
        matching: find.byType(RawImage),
      );
      // clearLiveImages evicts tracking records even while an Image widget owns
      // its frame. Assert the visible decoded frame, not a cache listener count.
      expect(displayed, findsOneWidget);
      final decoded = tester.widget<RawImage>(displayed).image;
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(128));
      expect(decoded.height, lessThanOrEqualTo(128));
      expect(portrait.hitTestable(), findsOneWidget);
      peakRss = peakRss < ProcessInfo.currentRss
          ? ProcessInfo.currentRss
          : peakRss;
      peakCache =
          peakCache < PaintingBinding.instance.imageCache.currentSizeBytes
          ? PaintingBinding.instance.imageCache.currentSizeBytes
          : peakCache;
      expect(
        PaintingBinding.instance.imageCache.currentSizeBytes,
        lessThanOrEqualTo(4 * 1024 * 1024),
      );
    }
    timer.stop();
    expect(controller.companion.name, 'Mầm native');
    expect(controller.companionLayout.lowResource, isTrue);
    for (final name in images) {
      await controller.removeCompanionAsset(name);
    }
    await controller.saveCompanion(originalProfile);
    await controller.updateCompanionLayout((v) => v.copy(lowResource: false));
    await tester.pumpAndSettle();
    debugPrint(
      'COMPANION_RESOURCE_POC: ${jsonEncode({'platform': Platform.operatingSystem, 'sourcePixels': '2048x2048', 'images': 4, 'selections': 24, 'lowResourceDecode': 128, 'rssBefore': rssBefore, 'rssAfterImport': rssAfterImport, 'rssSamplePeak': peakRss, 'rssAfterCleanup': ProcessInfo.currentRss, 'imageCacheSamplePeak': peakCache, 'importElapsedMs': importElapsedMs, 'selectionElapsedMs': timer.elapsedMilliseconds})}',
    );
    await animatedCompanionProbe(
      tester,
      controller,
      tester.element(find.byType(WorkspaceScreen)),
    );
    GoRouter.of(tester.element(find.byType(WorkspaceScreen))).go('/today');
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('RUN_ACCOUNT_EMULATOR')) {
      final host = ProviderScope.containerOf(
        tester.element(find.byType(WorkspaceScreen)),
      ).read(workspaceHostProvider)!;
      final localIds = host.controller!.tasks.map((t) => t.id).toSet();
      final artwork = await AccountArtworkProbe.start(tester, host);
      final email = '${const Uuid().v4()}@example.invalid',
          secret = const Uuid().v4();
      debugPrint('ACCOUNT_NATIVE_STAGE: create and open isolated workspace.');
      await host.signIn(email, secret, create: true, copyLocal: false);
      await tester.pumpAndSettle();
      await artwork.freshAccount(tester, host);
      final service = host.sync!;
      debugPrint('ACCOUNT_NATIVE_STAGE: initial sync.');
      await service.sync();
      expect(service.message, isNull);
      expect(host.controller!.tasks, isEmpty);
      final owner = host.account!.uid;
      expect((await secure.read())?.uid, owner);
      final privateTitle = 'Native account ${const Uuid().v4()}';
      final privateDay = tz.TZDateTime.now(tz.getLocation('Asia/Ho_Chi_Minh'));
      final privateId = await host.controller!.save(
        TaskDraft(
          title: privateTitle,
          dueAt: DateTime.now().add(const Duration(hours: 3)),
        ),
        repetition: RepeatChange(
          enabled: true,
          spec: RepeatSpec(
            frequency: RepeatFrequency.daily,
            zone: 'Asia/Ho_Chi_Minh',
            firstDate:
                '${privateDay.year}-${privateDay.month.toString().padLeft(2, '0')}-${privateDay.day.toString().padLeft(2, '0')}',
            minute: privateDay.hour * 60 + privateDay.minute + 1 < 1440
                ? privateDay.hour * 60 + privateDay.minute + 1
                : 1439,
          ),
        ),
      );
      await host.controller!.toggle(host.controller!.visibleTasks.first);
      await host.controller!.saveCompanion(
        CompanionProfile(
          name: 'Mầm tài khoản',
          templates: {'gentle:taskCompleted': '{name} mừng bạn xong {task}.'},
        ),
      );
      await androidSqliteProbe(tester, host);
      await resourceProbe(tester, host);
      await backupProbe(tester, host);
      await service.sync();
      expect(service.pendingCount, 0);
      expect(service.conflictCount, 0);
      final remote = await host.gateway.fetchAll(await host.session());
      expect(
        remote.any(
          (r) => jsonEncode(r.record.toJson()).contains(artwork.privateName!),
        ),
        isFalse,
      );
      expect(
        remote.any(
          (r) =>
              r.record.kind == SyncKind.task &&
              r.record.id == privateId &&
              r.record.data['title'] == privateTitle,
        ),
        isTrue,
      );
      expect(
        remote.any(
          (r) =>
              r.record.kind == SyncKind.companionProfile &&
              r.record.data['name'] == 'Mầm tài khoản',
        ),
        isTrue,
      );
      await host.notificationDevice(true);
      debugPrint('ACCOUNT_NATIVE_STAGE: primary device selected.');
      expect(host.controller!.reminders!.preferences.primaryDevice, isTrue);
      await host.signOut();
      debugPrint('ACCOUNT_NATIVE_STAGE: returned to local workspace.');
      await tester.pumpAndSettle();
      expect(await secure.read(), isNull);
      expect(host.controller!.tasks.map((t) => t.id).toSet(), localIds);
      expect(host.controller!.tasks.any((t) => t.id == privateId), isFalse);
      await artwork.localRestored(tester, host);
      await host.signIn(email, secret, create: false, copyLocal: false);
      debugPrint('ACCOUNT_NATIVE_STAGE: account reopened.');
      await tester.pumpAndSettle();
      await host.sync!.sync();
      expect(host.account!.uid, owner);
      expect(host.controller!.companion.name, 'Mầm tài khoản');
      await artwork.privateRestored(tester, host);
      expect(host.controller!.tasks.any((t) => t.id == privateId), isTrue);
      await host.deleteAccount(secret);
      debugPrint('ACCOUNT_NATIVE_STAGE: verified deletion completed.');
      await tester.pumpAndSettle();
      expect(host.account, isNull);
      expect(host.controller!.tasks.map((t) => t.id).toSet(), localIds);
      await artwork.finish(tester, host);
      debugPrint(
        'ACCOUNT_ARTWORK_POC: local/isolated/reopened/deleted artwork and native bitmaps passed.',
      );
      debugPrint(
        'ACCOUNT_NATIVE_POC: real Auth/Firestore, encrypted session, isolated profile, primary device, logout/relogin and verified deletion passed.',
      );
      final evidencePath =
          Platform.environment['DAYMIND_INSTALL_EVIDENCE_PATH'];
      if (Platform.isWindows && evidencePath != null) {
        await host.controller!.save(
          TaskDraft(
            title: 'Installer upgrade fixture',
            dueAt: DateTime.now().add(const Duration(days: 7)),
          ),
        );
        final name = await host.controller!.importer.installBytes(
          base64Decode(companionPngFixtures.first),
          'installer-fixture.png',
        );
        await host.controller!.configure((p) => p.copyWith(assetName: name));
        final evidence = File(evidencePath);
        await evidence.parent.create(recursive: true);
        await evidence.writeAsString(
          jsonEncode({'support': host.support.path}),
          flush: true,
        );
        debugPrint(
          'INSTALL_DATA_POC: private CI task database and original artwork prepared for installer upgrade.',
        );
      }
    }
  });
}
