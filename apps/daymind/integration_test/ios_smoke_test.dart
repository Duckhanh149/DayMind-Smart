import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:daymind_smart/main.dart' as app;
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/app/workspace_host.dart';
import 'package:daymind_smart/platform/notification_scheduler.dart';
import 'package:daymind_smart/platform/secure_session_store.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/tasks/presentation/workspace_screen.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';

import 'companion_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'iOS native startup Keychain SQLite reopen and owned artwork backup',
    (tester) async {
      expect(Platform.isIOS, isTrue);
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await app.main();
        await tester.pumpAndSettle();
        expect(find.byType(WorkspaceScreen), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(WorkspaceScreen)),
        );
        final host = container.read(workspaceHostProvider)!;
        final c = container.read(workspaceProvider);
        expect(host.syncConfigured, isFalse);
        expect(c.window, isNull);
        final scheduler =
            c.reminders!.engine.scheduler as PlatformNotificationScheduler;
        expect(scheduler.ready, isTrue, reason: scheduler.initializationError);
        expect(scheduler.osOwnsDelivery, isTrue);
        expect(scheduler.pendingLimit, 60);
        expect(await scheduler.pendingIds(), isNotNull);
        // No automatic permission request, no test override declaring OS permission.
        final allowed = await scheduler.granted();
        debugPrint(
          'IOS_PERMISSION_QUERY: ${allowed ? 'granted' : 'not_granted'}; no banner claim',
        );
        final secure = NativeSessionStore(namespace: 'production.daymind-ci.');
        final old = await secure.get('session');
        try {
          await secure.set('session', 'synthetic-ios-probe');
          expect(await secure.get('session'), 'synthetic-ios-probe');
          await secure.set('session', 'synthetic-ios-replaced');
          expect(await secure.get('session'), 'synthetic-ios-replaced');
          await secure.remove('session');
          expect(await secure.get('session'), isNull);
        } finally {
          if (old == null) {
            await secure.remove('session');
          } else {
            await secure.set('session', old);
          }
        }
        final support = await getApplicationSupportDirectory();
        final root = await Directory(p.join(support.path, 'ios-qa'))
            .create(recursive: true);
        DaymindDatabase? db;
        StaticAssetImporter? importer, restored;
        try {
          final file = File(p.join(root.path, 'reopen.sqlite'));
          db = DaymindDatabase(NativeDatabase.createInBackground(file));
          var repo = SqliteTaskRepository(db);
          final id = await repo.save(
            TaskDraft(title: 'Synthetic iOS offline task'),
          );
          await db.close();
          db = null;
          db = DaymindDatabase(NativeDatabase.createInBackground(file));
          repo = SqliteTaskRepository(db);
          var row = (await repo.list()).single;
          expect(row.id, id);
          expect(row.title, 'Synthetic iOS offline task');
          await repo.save(
            TaskDraft(title: 'Edited offline', status: TaskStatus.completed),
            id: id,
            expectedRevision: row.revision,
          );
          row = (await repo.list()).single;
          expect(row.status, TaskStatus.completed);
          await repo.delete(id, row.revision);
          row = (await repo.list()).single;
          expect(row.deletedAt, isNotNull);
          await repo.restore(id, row.revision);
          expect((await repo.list()).single.deletedAt, isNull);
          expect(
            (await db.customSelect('PRAGMA integrity_check').get())
                .single
                .data
                .values
                .single,
            'ok',
          );
          importer = StaticAssetImporter(
            Directory(p.join(root.path, 'characters')),
          );
          final picked = File(p.join(root.path, 'picked.png'));
          await picked.writeAsBytes(base64Decode(companionPngFixtures.first));
          final name = await importer.install(picked, 'synthetic.png');
          await picked.delete();
          expect(await importer.renderFile(name), isNotNull);
          final files = await importer.backupFiles(name);
          restored = StaticAssetImporter(
            Directory(p.join(root.path, 'restored')),
          );
          final copy = await restored.restoreBackupFiles(name, files);
          expect(await restored.renderFile(copy), isNotNull);
          debugPrint(
            'IOS_NATIVE_SMOKE: Keychain scoped replace/delete, SQLite background worker reopen/CRUD/integrity, owned image and asset-backup roundtrip passed',
          );
        } finally {
          await db?.close();
          await importer?.drain();
          await restored?.drain();
          if (await root.exists()) await root.delete(recursive: true);
          await host.shutdown();
          await tester.pumpWidget(const SizedBox.shrink());
        }
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    },
  );
}
