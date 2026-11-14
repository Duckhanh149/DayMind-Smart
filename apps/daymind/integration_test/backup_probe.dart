import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:daymind_smart/app/workspace_host.dart';
import 'package:daymind_smart/features/backup/data/backup_codec.dart';
import 'package:daymind_smart/features/backup/domain/backup_snapshot.dart';
import 'package:daymind_smart/features/account_sync/domain/sync_record.dart';
import 'package:daymind_smart/features/recurrence/domain/recurrence.dart';

/// Actual app/SQLite/asset/native-scheduler path inside the disposable Emulator
/// account. No production credentials or user data are used or printed.
Future<void> backupProbe(WidgetTester tester, WorkspaceHost host) async {
  final c = host.controller!, owner = host.account!.uid;
  final originalIds = c.tasks.map((t) => t.id).toSet();
  final originalActiveIds = c.tasks
      .where((t) => t.deletedAt == null)
      .map((t) => t.id)
      .toSet();
  final originalTrashIds = c.tasks
      .where((t) => t.deletedAt != null)
      .map((t) => t.id)
      .toSet();
  final originalCompleted = c.visibleTasks
      .where((t) => t.status.name == 'completed' && t.deletedAt == null)
      .map((t) => t.id)
      .toSet();
  final notifications = c.reminders!.preferences.toJson(),
      floating = c.floatingSettings;
  await c.reminders!.configure({'quietEnabled': false});
  await host.notificationDevice(true);
  await c.reminders!.refresh();
  // A refresh coalesced with the native/sync poll returns before that poll's
  // queued replan. Wait for persisted scheduling, rather than the UI cache.
  final ready = Stopwatch()..start();
  var events = await c.reminders!.engine.events();
  bool scheduled() => events.any(
    (e) => e.state == 'scheduled' && originalIds.contains(e.taskId),
  );
  while (!scheduled() && ready.elapsed < const Duration(seconds: 10)) {
    await tester.pump(const Duration(milliseconds: 100));
    events = await c.reminders!.engine.events();
  }
  final prefs = await c.reminders!.engine.preferences();
  debugPrint(
    'BACKUP_SCHEDULING_PRECONDITION: ${jsonEncode({
      'primary': prefs.primaryDevice,
      'granted': await c.reminders!.engine.scheduler.granted(),
      'quiet': prefs.quietEnabled,
      'preset': prefs.preset.name,
      'projectedTasks': c.visibleTasks.length,
      'eventStates': {for (final state in events.map((e) => e.state).toSet()) state: events.where((e) => e.state == state).length},
      'coordinatorError': c.reminders!.error != null,
    })}',
  );
  expect(
    scheduled(),
    isTrue,
    reason: 'The restore probe must start with an actual future reminder to cancel.',
  );
  final scheduledBefore = events.where((e) => e.state == 'scheduled').length;
  final rss = ProcessInfo.currentRss, clock = Stopwatch()..start();
  final snapshot = await host.captureBackup();
  expect(snapshot.owner, owner);
  expect(snapshot.taskCount, greaterThan(0));
  expect(snapshot.assets, isNotEmpty);
  expect(snapshot.records.any((r) => r.kind == SyncKind.recurrence), isTrue);
  expect(snapshot.records.any((r) => r.kind == SyncKind.occurrence), isTrue);
  final secret = const Uuid().v4();
  final captureMs = clock.elapsedMilliseconds;
  final encoded = await BackupCodec.encrypt(snapshot, secret);
  final encryptedMs = clock.elapsedMilliseconds - captureMs;
  final folder = await Directory.systemTemp.createTemp(
    'daymind-backup-native-',
  );
  try {
    final file = await File('${folder.path}/fixture.daymind')
        .writeAsBytes(encoded, flush: true);
    final bytes = await file.readAsBytes();
    expect(String.fromCharCodes(bytes), isNot(contains(owner)));
    await expectLater(
      BackupCodec.decrypt(bytes, 'wrong-test-only-password'),
      throwsA(isA<BackupFailure>()),
    );
    expect(c.tasks.map((t) => t.id).toSet(), originalIds);
    final restored = await BackupCodec.decrypt(bytes, secret);
    Future<int> displayed() async =>
        (await c.repository.db.select(c.repository.db.deliveryLogs).get())
            .where(
              (e) =>
                  e.outcome.contains('display_attempt') ||
                  e.outcome == 'in_app',
            )
            .length;
    final delivered = await displayed();
    await host.restoreBackup(restored, companionSettings: false);
    await tester.pump(const Duration(milliseconds: 500));
    final integrity = await c.repository.db
        .customSelect('PRAGMA integrity_check')
        .get();
    expect(integrity, hasLength(1));
    expect(integrity.single.data.values.single, 'ok');
    expect(c.tasks.length, originalIds.length + snapshot.taskCount);
    expect(c.reminders!.preferences.primaryDevice, isFalse);
    expect(c.reminders!.preferences.digestEnabled, isFalse);
    expect(await displayed(), delivered);
    expect(c.reminders!.events.any((e) => e.state == 'scheduled'), isFalse);
    for (final asset in snapshot.assets) {
      expect(await c.importer.backupFiles(asset.name), asset.files);
    }
    await expectLater(
      host.restoreBackup(restored, companionSettings: false),
      throwsA(isA<BackupFailure>()),
    );
    // Keep the surrounding account/artwork gate's original active tasks/settings.
    for (final task
        in c.tasks
            .where((t) => !originalIds.contains(t.id) && t.deletedAt == null)
            .toList()) {
      await c.delete(task, scope: EditScope.all);
    }
    await c.reminders!.configure(notifications);
    await c.updateFloating((_) => floating);
    await host.sync!.sync();
    expect(host.sync!.message, isNull);
    expect(
      c.tasks.where((t) => t.deletedAt == null).map((t) => t.id).toSet(),
      originalActiveIds,
    );
    expect(
      c.tasks
          .where((t) => t.deletedAt != null)
          .map((t) => t.id)
          .toSet()
          .containsAll(originalTrashIds),
      isTrue,
    );
    expect(
      c.visibleTasks
          .where((t) => t.status.name == 'completed')
          .map((t) => t.id)
          .toSet()
          .containsAll(originalCompleted),
      isTrue,
    );
    debugPrint(
      'BACKUP_NATIVE_POC: ${jsonEncode({'platform': Platform.operatingSystem, 'tasks': snapshot.taskCount, 'assets': snapshot.assets.length, 'recurrenceGroups': snapshot.records.where((r) => r.kind == SyncKind.recurrence).length, 'preservedOccurrences': snapshot.records.where((r) => r.kind == SyncKind.occurrence).length, 'scheduledBefore': scheduledBefore, 'cipherBytes': encoded.length, 'captureMs': captureMs, 'encryptMs': encryptedMs, 'totalProbeMs': clock.elapsedMilliseconds, 'rssBefore': rss, 'rssAfter': ProcessInfo.currentRss, 'wrongPasswordRejected': true, 'atomicCopyAndNoReplay': true})}',
    );
  } finally {
    await folder.delete(recursive: true);
  }
}
