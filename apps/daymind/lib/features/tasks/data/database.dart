import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/task.dart' as domain;
part 'database.g.dart';

@DataClassName('CategoryRecord')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get color => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TaskRecord')
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 240)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get priority =>
      integer().customConstraint('NOT NULL CHECK (priority BETWEEN 0 AND 2)')();
  IntColumn get status =>
      integer().customConstraint('NOT NULL CHECK (status BETWEEN 0 AND 3)')();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get scheduledStartAt => dateTime().nullable()();
  DateTimeColumn get scheduledEndAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  @override
  Set<Column> get primaryKey => {id};
}

class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Categories, Tasks, Preferences])
class DaymindDatabase extends _$DaymindDatabase {
  DaymindDatabase(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from == 1) {
        await m.addColumn(tasks, tasks.scheduledStartAt);
        await m.addColumn(tasks, tasks.scheduledEndAt);
        await m.addColumn(tasks, tasks.revision);
        await m.createTable(preferences);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
      if (details.wasCreated) {
        await batch(
          (b) => b.insertAll(categories, [
            CategoriesCompanion.insert(
              id: 'work',
              name: 'Công việc',
              color: 0xffb97156,
            ),
            CategoriesCompanion.insert(
              id: 'personal',
              name: 'Cá nhân',
              color: 0xff6b8b72,
            ),
            CategoriesCompanion.insert(
              id: 'learning',
              name: 'Học tập',
              color: 0xff8a7cb2,
            ),
          ]),
        );
      }
    },
  );
}

class SqliteTaskRepository implements domain.TaskRepository {
  SqliteTaskRepository(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DaymindDatabase db;
  final DateTime Function() clock;
  domain.Task _model(TaskRecord row) => domain.Task(
    id: row.id,
    title: row.title,
    description: row.description,
    priority: domain.TaskPriority.values[row.priority],
    status: domain.TaskStatus.values[row.status],
    categoryId: row.categoryId,
    dueAt: row.dueAt?.toUtc(),
    scheduledStartAt: row.scheduledStartAt?.toUtc(),
    scheduledEndAt: row.scheduledEndAt?.toUtc(),
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
    completedAt: row.completedAt?.toUtc(),
    deletedAt: row.deletedAt?.toUtc(),
    revision: row.revision,
  );
  @override
  Future<List<domain.Task>> list() async =>
      (await db.select(db.tasks).get()).map(_model).toList();
  @override
  Future<List<domain.Category>> categories() async =>
      (await db.select(db.categories).get())
          .map((row) => domain.Category(row.id, row.name, row.color))
          .toList();
  @override
  Future<String> save(
    domain.TaskDraft draft, {
    String? id,
    int? expectedRevision,
  }) {
    draft.validate();
    return db.transaction(() async {
      TaskRecord? old;
      if (id != null) {
        old =
            await (db.select(db.tasks)
                  ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
                .getSingleOrNull();
        if (old == null || expectedRevision != old.revision) {
          throw const domain.EditConflict();
        }
      }
      final taskId = id ?? const Uuid().v4(), now = clock().toUtc();
      final completedAt = draft.status == domain.TaskStatus.completed
          ? old?.completedAt ?? now
          : null;
      final row = TasksCompanion.insert(
        id: taskId,
        title: draft.title.trim(),
        description: Value(draft.description.trim()),
        priority: draft.priority.index,
        status: draft.status.index,
        categoryId: Value(draft.categoryId),
        dueAt: Value(draft.dueAt?.toUtc()),
        scheduledStartAt: Value(draft.scheduledStartAt?.toUtc()),
        scheduledEndAt: Value(draft.scheduledEndAt?.toUtc()),
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
        completedAt: Value(completedAt),
        revision: Value((old?.revision ?? 0) + 1),
      );
      if (old == null) {
        await db.into(db.tasks).insert(row);
      } else {
        await (db.update(
          db.tasks,
        )..where((t) => t.id.equals(taskId))).write(row);
      }
      return taskId;
    });
  }

  Future<void> _tombstone(String id, int revision, {required bool restore}) =>
      db.transaction(() async {
        final old = await (db.select(
          db.tasks,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (old == null ||
            old.revision != revision ||
            (restore ? old.deletedAt == null : old.deletedAt != null)) {
          throw const domain.EditConflict();
        }
        await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
          TasksCompanion(
            deletedAt: Value(restore ? null : clock().toUtc()),
            updatedAt: Value(clock().toUtc()),
            revision: Value(revision + 1),
          ),
        );
      });
  @override
  Future<void> delete(String id, int expectedRevision) =>
      _tombstone(id, expectedRevision, restore: false);
  @override
  Future<void> restore(String id, int expectedRevision) =>
      _tombstone(id, expectedRevision, restore: true);
  @override
  Future<void> addCategory(String name, int color) => db.transaction(() async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 40) {
      throw const domain.ValidationException(
        'Tên danh mục cần từ 1 đến 40 ký tự.',
      );
    }
    if ((await categories()).any(
      (category) => category.name.toLowerCase() == clean.toLowerCase(),
    )) {
      throw const domain.ValidationException('Danh mục đã tồn tại.');
    }
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: const Uuid().v4(),
            name: clean,
            color: color,
          ),
        );
  });
  Future<Map<String, dynamic>> readPreferences() async {
    final row = await (db.select(
      db.preferences,
    )..where((p) => p.key.equals('app'))).getSingleOrNull();
    return row == null ? {} : jsonDecode(row.value) as Map<String, dynamic>;
  }

  Future<void> writePreferences(Map<String, dynamic> value) => db
      .into(db.preferences)
      .insertOnConflictUpdate(
        PreferencesCompanion.insert(key: 'app', value: jsonEncode(value)),
      );
}
