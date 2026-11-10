import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:daymind_smart/app/workspace_host.dart';
import 'package:daymind_smart/features/backup/data/backup_codec.dart';
import 'package:daymind_smart/features/backup/domain/backup_snapshot.dart';

/// Actual app/SQLite/asset/native-scheduler path inside the disposable Emulator
/// account. No production credentials or user data are used or printed.
Future<void> backupProbe(WidgetTester tester, WorkspaceHost host) async {
  final c = host.controller!, owner = host.account!.uid;
  final originalIds = c.tasks.map((t) => t.id).toSet();
  final notifications = c.reminders!.preferences.toJson(),
      floating = c.floatingSettings;
  final rss = ProcessInfo.currentRss, clock = Stopwatch()..start();
  final snapshot = await host.captureBackup();
  expect(snapshot.owner, owner);
  expect(snapshot.taskCount, greaterThan(0));
  expect(snapshot.assets, isNotEmpty);
  final secret = const Uuid().v4();
  final encoded = await BackupCodec.encrypt(snapshot, secret);
  final encryptedMs = clock.elapsedMilliseconds;
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
    final delivered =
        (await c.repository.db.select(c.repository.db.deliveryLogs).get())
            .length;
    await host.restoreBackup(restored, companionSettings: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.tasks.length, originalIds.length + snapshot.taskCount);
    expect(c.reminders!.preferences.primaryDevice, isFalse);
    expect(c.reminders!.preferences.digestEnabled, isFalse);
    expect(
      (await c.repository.db.select(c.repository.db.deliveryLogs).get()).length,
      delivered,
    );
    for (final asset in snapshot.assets) {
      expect(await c.importer.backupFiles(asset.name), asset.files);
    }
    await expectLater(
      host.restoreBackup(restored, companionSettings: false),
      throwsA(isA<BackupFailure>()),
    );
    // Keep the surrounding account/artwork gate's original active tasks/settings.
    for (final task
        in c.tasks.where((t) => !originalIds.contains(t.id)).toList()) {
      await c.delete(task);
    }
    await c.reminders!.configure(notifications);
    await c.updateFloating((_) => floating);
    await host.sync!.sync();
    expect(host.sync!.message, isNull);
    expect(
      c.visibleTasks.where((t) => t.deletedAt == null).map((t) => t.id).toSet(),
      originalIds,
    );
    debugPrint(
      'BACKUP_NATIVE_POC: ${jsonEncode({'platform': Platform.operatingSystem, 'tasks': snapshot.taskCount, 'assets': snapshot.assets.length, 'cipherBytes': encoded.length, 'encryptMs': encryptedMs, 'totalProbeMs': clock.elapsedMilliseconds, 'rssBefore': rss, 'rssAfter': ProcessInfo.currentRss, 'wrongPasswordRejected': true, 'atomicCopyAndNoReplay': true})}',
    );
  } finally {
    await folder.delete(recursive: true);
  }
}
