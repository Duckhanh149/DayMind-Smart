import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';
import 'package:daymind_smart/features/account_sync/data/workspace_records.dart';
import 'package:daymind_smart/features/account_sync/domain/sync_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DaymindDatabase db;
  late WorkspaceController c;
  late Directory temp;
  setUp(() async {
    db = DaymindDatabase(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('daymind-companion-');
    c = WorkspaceController(
      SqliteTaskRepository(db),
      StaticAssetImporter(temp),
    );
    await c.load();
  });
  tearDown(() async {
    c.dispose();
    await db.close();
    await temp.delete(recursive: true);
  });
  test(
    'profile persists, stale editors cannot overwrite a newer sync result',
    () async {
      final original = c.companion;
      final newer = original.copy(name: 'Mầm từ máy khác');
      await c.recurrence.records.put(
        'companion_profile',
        'primary',
        newer.toJson(),
      );
      await c.refreshFromSync();
      final draft = original.copy(name: 'Bản đang soạn');
      await expectLater(
        c.saveCompanion(draft, expected: original),
        throwsA(isA<CompanionValidation>()),
      );
      expect(c.companion.name, newer.name);
      expect(draft.name, 'Bản đang soạn');
      final next = newer.copy(
        templates: {'gentle:taskCompleted': '{name} đã xong {task}.'},
        expressions: {CompanionEvent.taskCompleted: CompanionExpression.happy},
      );
      await c.saveCompanion(next, expected: newer);
      await c.load();
      expect(c.companion.sameAs(next), isTrue);
      expect(
        c.companion.messageFor(CompanionEvent.taskCompleted, task: 'Đọc sách'),
        'Mầm từ máy khác đã xong Đọc sách.',
      );
    },
  );
  test('queued local layout changes preserve independent fields and do not trigger cloud writes', () async {
    var uploads = 0;
    c.onLocalChange = () => uploads++;
    await Future.wait([
      c.updateCompanionLayout(
        (v) => v.copy(placement: CompanionPlacement.right, size: 144),
      ),
      c.updateCompanionLayout((v) => v.copy(lowResource: true)),
    ]);
    await c.load();
    expect(c.companionLayout.placement, CompanionPlacement.right);
    expect(c.companionLayout.size, 144);
    expect(c.companionLayout.lowResource, isTrue);
    expect(
      PaintingBinding.instance.imageCache.maximumSizeBytes,
      4 * 1024 * 1024,
    );
    expect(uploads, 0);
    expect(
      (await WorkspaceRecords(
        c.repository,
      ).read()).values.where((r) => r.kind == SyncKind.companionProfile),
      isEmpty,
    );
  });
  test(
    'asset deletion clears all local references without uploading file names',
    () async {
      final name = '${'a' * 64}.png';
      await File('${temp.path}/$name').writeAsBytes([1]);
      await c.configure((p) => p.copyWith(assetName: name));
      await c.mapExpression(CompanionExpression.happy, name);
      await c.saveCompanion(c.companion.copy(name: 'Lá'));
      final records = (await WorkspaceRecords(c.repository).read()).values;
      final record = records.singleWhere(
        (r) => r.kind == SyncKind.companionProfile,
      );
      expect(record.data.toString(), isNot(contains(name)));
      expect(record.data.keys, isNot(contains('layout')));
      await c.removeCompanionAsset(name);
      expect(c.preferences.assetName, isNull);
      expect(c.expressionAssets, isEmpty);
      expect(c.importer.installed(), isEmpty);
      await c.load();
      expect(c.expressionAssets, isEmpty);
    },
  );
  test(
    'visible overdue hint survives process restart without OS notifications',
    () async {
      var instant = DateTime.utc(2026, 1, 5, 9);
      c.dispose();
      c = WorkspaceController(
        SqliteTaskRepository(db, clock: () => instant),
        StaticAssetImporter(temp),
        clock: () => instant,
      );
      await c.load();
      await c.save(
        TaskDraft(
          title: 'Việc cũ',
          dueAt: instant.subtract(const Duration(hours: 1)),
        ),
      );
      instant = instant.add(const Duration(seconds: 31));
      await c.overdueVisible();
      expect(
        (await c.recurrence.records.get('companion_local', 'overdue'))?['day'],
        '2026-01-05',
      );
      c.dispose();
      instant = instant.add(const Duration(hours: 1));
      c = WorkspaceController(
        SqliteTaskRepository(db, clock: () => instant),
        StaticAssetImporter(temp),
        clock: () => instant,
      );
      await c.load();
      final greeting = c.dialogue;
      instant = instant.add(const Duration(seconds: 31));
      await c.overdueVisible();
      expect(c.dialogue, greeting);
      instant = instant.add(const Duration(days: 1));
      await c.overdueVisible();
      expect(
        (await c.recurrence.records.get('companion_local', 'overdue'))?['day'],
        '2026-01-06',
      );
      expect(await db.select(db.reminderEvents).get(), isEmpty);
    },
  );
  test('disabled companion still delivers foreground announcements and leaves tasks usable', () async {
    await c.configure((p) => p.copyWith(companionEnabled: false));
    final previous = c.dialogue;
    c.foregroundReminder(
      const CompanionCue(
        CompanionEvent.reminderDue,
        'Đến giờ đọc sách',
        task: 'Đọc sách',
      ),
    );
    expect(c.inAppSequence, 1);
    expect(c.inAppAnnouncement, 'Đến giờ đọc sách');
    expect(c.dialogue, previous);
    await c.save(const TaskDraft(title: 'Đọc sách'));
    await c.toggle(c.tasks.single);
    expect(c.tasks.single.status, TaskStatus.completed);
    expect(await db.select(db.reminderEvents).get(), isEmpty);
  });
}
