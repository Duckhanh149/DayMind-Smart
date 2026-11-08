import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';

void main() {
  final now = DateTime.utc(2026, 11, 8, 3);
  late DaymindDatabase db;
  late SqliteTaskRepository repo;
  setUp(() {
    db = DaymindDatabase(NativeDatabase.memory());
    repo = SqliteTaskRepository(db, clock: () => now);
  });
  tearDown(() => db.close());
  test('title and scheduled interval validation; deadline is optional', () {
    expect(
      () => const TaskDraft(title: ' ').validate(),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => TaskDraft(title: 'x' * 241).validate(),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => TaskDraft(
        title: 'Plan',
        scheduledStartAt: now,
        scheduledEndAt: now.subtract(const Duration(hours: 1)),
      ).validate(),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => TaskDraft(
        title: 'Plan',
        dueAt: now,
        scheduledEndAt: now.add(const Duration(hours: 1)),
      ).validate(),
      returnsNormally,
    );
  });
  test('SQLite creates categories and task without deadline', () async {
    expect((await repo.categories()).length, 3);
    await repo.save(const TaskDraft(title: '  Gặp chị Ánh 🌱  '));
    final task = (await repo.list()).single;
    expect(task.title, 'Gặp chị Ánh 🌱');
    expect(task.dueAt, isNull);
    expect(task.revision, 1);
  });
  test(
    'completion, reopening and revisions survive SQLite round trip',
    () async {
      final id = await repo.save(const TaskDraft(title: 'Việc'));
      await repo.save(
        const TaskDraft(title: 'Việc', status: TaskStatus.completed),
        id: id,
        expectedRevision: 1,
      );
      expect((await repo.list()).single.completedAt, now);
      await repo.save(
        const TaskDraft(title: 'Việc'),
        id: id,
        expectedRevision: 2,
      );
      expect((await repo.list()).single.completedAt, isNull);
      expect((await repo.list()).single.revision, 3);
    },
  );
  test('stale edits and deletes preserve newer text', () async {
    final id = await repo.save(const TaskDraft(title: 'Bản cũ'));
    await repo.save(
      const TaskDraft(title: 'Bản mới'),
      id: id,
      expectedRevision: 1,
    );
    await expectLater(
      repo.save(const TaskDraft(title: 'Ghi đè'), id: id, expectedRevision: 1),
      throwsA(isA<EditConflict>()),
    );
    await expectLater(repo.delete(id, 1), throwsA(isA<EditConflict>()));
    expect((await repo.list()).single.title, 'Bản mới');
    expect((await repo.list()).single.deletedAt, isNull);
  });
  test(
    'soft delete and restore check revision and do not lose task text',
    () async {
      final id = await repo.save(const TaskDraft(title: 'Giữ lại'));
      await repo.delete(id, 1);
      expect((await repo.list()).single.deletedAt, now);
      expect(
        filterTasks(await repo.list(), view: TaskView.all, now: now),
        isEmpty,
      );
      await expectLater(repo.restore(id, 1), throwsA(isA<EditConflict>()));
      await repo.restore(id, 2);
      expect((await repo.list()).single.deletedAt, isNull);
      expect((await repo.list()).single.title, 'Giữ lại');
    },
  );
  test(
    'transaction rollback and foreign keys prevent partial writes',
    () async {
      await expectLater(
        db.transaction(() async {
          await repo.save(const TaskDraft(title: 'Không được giữ'));
          await repo.save(const TaskDraft(title: 'Lỗi', categoryId: 'missing'));
        }),
        throwsA(anything),
      );
      expect(await repo.list(), isEmpty);
    },
  );
  test('category validation and duplicate detection', () async {
    await expectLater(
      repo.addCategory(' ', 0xff123456),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      repo.addCategory('công việc', 0xff123456),
      throwsA(isA<ValidationException>()),
    );
    await repo.addCategory('Sức khỏe', 0xff123456);
    expect((await repo.categories()).length, 4);
  });
  test(
    'scheduled-only tasks appear in upcoming without inventing deadlines',
    () async {
      await repo.save(
        TaskDraft(
          title: 'Lịch hẹn',
          scheduledStartAt: now.add(const Duration(days: 2)),
        ),
      );
      final items = filterTasks(
        await repo.list(),
        view: TaskView.upcoming,
        now: now,
      );
      expect(items.single.title, 'Lịch hẹn');
      expect(items.single.dueAt, isNull);
    },
  );
  test(
    'overdue is derived and cancelled/completed/deleted tasks are excluded',
    () async {
      await repo.save(
        TaskDraft(
          title: 'Quá hạn',
          dueAt: now.subtract(const Duration(days: 1)),
        ),
      );
      await repo.save(
        TaskDraft(
          title: 'Đã hủy',
          dueAt: now.subtract(const Duration(days: 1)),
          status: TaskStatus.cancelled,
        ),
      );
      expect(
        filterTasks(await repo.list(), view: TaskView.today, now: now).length,
        1,
      );
      expect((await repo.list()).where((t) => t.overdue(now)).length, 1);
    },
  );
  test('search and category/priority filtering preserve Unicode', () async {
    await repo.save(
      const TaskDraft(
        title: 'HỌC tiếng Việt',
        priority: TaskPriority.high,
        categoryId: 'learning',
      ),
    );
    await repo.save(const TaskDraft(title: 'Việc khác'));
    expect(
      filterTasks(
        await repo.list(),
        view: TaskView.all,
        now: now,
        search: 'tiếng việt',
        category: 'learning',
        priority: TaskPriority.high,
      ).length,
      1,
    );
  });
  test(
    'file persistence and preferences survive closing and reopening',
    () async {
      final temp = await Directory.systemTemp.createTemp('daymind-restart-');
      final file = File('${temp.path}/data.sqlite');
      var disk = DaymindDatabase(NativeDatabase(file));
      var repository = SqliteTaskRepository(disk);
      await repository.save(const TaskDraft(title: 'Sau khi mở lại'));
      await repository.writePreferences(
        const AppPreferences(theme: 'dark', companionEnabled: false).toJson(),
      );
      await disk.close();
      disk = DaymindDatabase(NativeDatabase(file));
      repository = SqliteTaskRepository(disk);
      expect((await repository.list()).single.title, 'Sau khi mở lại');
      expect(
        AppPreferences.fromJson(await repository.readPreferences())
            .companionEnabled,
        false,
      );
      await disk.close();
      await temp.delete(recursive: true);
    },
  );
  test(
    'v1 migration preserves old text and adds scheduling/revision/preferences',
    () async {
      final temp = await Directory.systemTemp.createTemp('daymind-migrate-');
      final file = File('${temp.path}/old.sqlite');
      final old = sqlite.sqlite3.open(file.path);
      old.execute(
        'CREATE TABLE categories(id TEXT PRIMARY KEY, name TEXT NOT NULL, color INTEGER NOT NULL)',
      );
      old.execute(
        'CREATE TABLE tasks(id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT NOT NULL, priority INTEGER NOT NULL, status INTEGER NOT NULL, category_id TEXT, due_at INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, completed_at INTEGER, deleted_at INTEGER)',
      );
      old.execute(
        "INSERT INTO tasks VALUES ('old','Không mất dữ liệu','',1,0,NULL,NULL,1,1,NULL,NULL)",
      );
      old.execute('PRAGMA user_version=1');
      old.close();
      final migrated = DaymindDatabase(NativeDatabase(file));
      final repository = SqliteTaskRepository(migrated);
      final task = (await repository.list()).single;
      expect(task.title, 'Không mất dữ liệu');
      expect(task.revision, 1);
      expect(task.scheduledStartAt, isNull);
      await repository.writePreferences({'theme': 'dark'});
      expect((await repository.readPreferences())['theme'], 'dark');
      await migrated.close();
      await temp.delete(recursive: true);
    },
  );
  test('companion dialogue has cooldown and no independent timer', () {
    var instant = now;
    final behavior = CompanionBehavior(clock: () => instant);
    expect(
      behavior.respond(CompanionEvent.appOpen, Personality.gentle),
      isNotNull,
    );
    expect(
      behavior.respond(CompanionEvent.taskCompleted, Personality.gentle),
      isNull,
    );
    instant = instant.add(const Duration(seconds: 31));
    expect(
      behavior.respond(CompanionEvent.taskCompleted, Personality.practical),
      contains('hoàn thành'),
    );
  });
  test('invalid companion metadata cannot escape local asset directory', () {
    expect(
      AppPreferences.fromJson({'assetName': '../private.txt'}).assetName,
      isNull,
    );
    expect(AppPreferences.fromJson({'companionSize': 500}).companionSize, 112);
    expect(
      AppPreferences.fromJson({'personality': 'unknown'}).personality,
      Personality.gentle,
    );
  });
}
