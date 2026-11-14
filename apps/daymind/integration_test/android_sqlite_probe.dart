import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/app/workspace_host.dart';
import 'package:daymind_smart/platform/notification_scheduler.dart';

/// Hold actual Dart write transactions while the private Android process runs
/// recovery against the same fixture. No second engine or test override exists.
Future<void> androidSqliteProbe(WidgetTester tester, WorkspaceHost host) async {
  if (!Platform.isAndroid) return;
  final db = host.controller!.repository.db;
  Future<void> integrity() async {
    final rows = await db.customSelect('PRAGMA integrity_check').get();
    expect(rows, hasLength(1));
    expect(rows.single.data.values.single, 'ok');
  }

  expect(
    await PlatformNotificationScheduler.channel.invokeMethod<bool>(
      'runtimeIsolation',
    ),
    isTrue,
  );
  await integrity();
  final path =
      '${workspacePath(host.support.path, host.account?.uid)}/daymind.sqlite';
  for (var round = 0; round < 5; round++) {
    final entered = Completer<void>(), release = Completer<void>();
    final transaction = db.transaction(() async {
      await db.customStatement(
        "INSERT OR REPLACE INTO extension_records(area,id,value,updated_ms) VALUES('qa_sqlite','probe',?,?)",
        ['{"round":$round}', DateTime.now().millisecondsSinceEpoch],
      );
      entered.complete();
      await release.future;
    });
    // Forward a SQL failure instead of waiting for a transaction never entered.
    unawaited(
      transaction.catchError((Object error, StackTrace stack) {
        if (!entered.isCompleted) entered.completeError(error, stack);
      }),
    );
    await entered.future;
    final recovery = PlatformNotificationScheduler.channel.invokeMethod<void>(
      'initialize',
      {'path': path},
    );
    try {
      await tester.pump(const Duration(milliseconds: 100));
    } finally {
      release.complete();
      await transaction;
    }
    await recovery;
    await integrity();
  }
  await db.customStatement(
    "DELETE FROM extension_records WHERE area='qa_sqlite' AND id='probe'",
  );
  debugPrint(
    'ANDROID_SQLITE_ISOLATION_POC: separate native process, five overlapping write/recovery cycles and integrity_check passed.',
  );
}
