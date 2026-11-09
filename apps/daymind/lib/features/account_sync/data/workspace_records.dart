import 'package:drift/drift.dart';

import '../../../core/record_store.dart';
import '../../tasks/data/database.dart';
import '../../tasks/domain/task.dart' as domain;
import '../../recurrence/domain/recurrence.dart';
import '../../recurrence/application/recurrence_service.dart';
import '../../reminders/domain/reminder.dart';
import '../domain/account.dart';
import '../domain/sync_record.dart';

class WorkspaceRecords {
  WorkspaceRecords(this.repository, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now,
      records = RecordStore(repository.db);
  final SqliteTaskRepository repository;
  final RecordStore records;
  final DateTime Function() clock;
  DaymindDatabase get db => repository.db;

  Future<Map<String, SyncRecord>> read({bool validateRelations = true}) async {
    final result = <String, SyncRecord>{};
    void add(SyncRecord record) {
      result[record.key] = record;
    }

    final tasks = await repository.list(),
        categories = await repository.categories();
    final rules = (await records.list('recurrence'))
        .map(RecurrenceRule.fromJson)
        .toList();
    final occurrences = (await records.list('occurrences'))
        .map(TaskOccurrence.fromJson)
        .toList();
    final modes = await records.list('task_reminders');
    final reminderRules = (await records.list('reminder_rules'))
        .map(ReminderRule.fromJson)
        .toList();
    final taskIds = tasks.map((t) => t.id).toSet();
    final ruleById = {for (final r in rules) r.id: r};
    final occurrenceById = {for (final o in occurrences) o.id: o};
    String parent(String scope) {
      if (taskIds.contains(scope)) return scope;
      final value = ruleById[scope]?.taskId ?? occurrenceById[scope]?.taskId;
      if (value == null) {
        throw const AccountFailure(
          'invalid_relations',
          'Cấu hình không thuộc công việc nào. Dữ liệu vẫn được giữ trên thiết bị.',
        );
      }
      return value;
    }

    for (final c in categories) {
      add(
        SyncRecord(
          kind: SyncKind.category,
          id: c.id,
          data: {'name': c.name, 'color': c.color},
        ),
      );
    }
    for (final t in tasks) {
      add(
        SyncRecord(
          kind: SyncKind.task,
          id: t.id,
          data: {
            ...domain.TaskDraft.fromTask(t).toJson(),
            'createdAt': t.createdAt.toUtc().toIso8601String(),
            'updatedAt': t.updatedAt.toUtc().toIso8601String(),
            'completedAt': t.completedAt?.toUtc().toIso8601String(),
            'deletedAt': t.deletedAt?.toUtc().toIso8601String(),
          },
        ),
      );
    }
    for (final id in rules.map((r) => r.taskId).toSet()) {
      add(
        SyncRecord(
          kind: SyncKind.recurrence,
          id: id,
          data: {
            'taskId': id,
            'rules': [
              for (final r in rules.where((r) => r.taskId == id))
                r.toJson()..remove('revision'),
            ],
          },
        ),
      );
    }
    final referenced = modes.map((m) => m['id'] as String).toSet();
    for (final o in occurrences) {
      final explicitDelete = o.deleted && !o.retired;
      if (!o.terminal &&
          !o.detached &&
          !explicitDelete &&
          o.overrides.isEmpty &&
          o.draft.status == domain.TaskStatus.todo &&
          !referenced.contains(o.id)) {
        continue;
      }
      add(
        SyncRecord(
          kind: SyncKind.occurrence,
          id: o.id,
          data: {
            'taskId': o.taskId,
            'ruleId': o.ruleId,
            'date': o.date,
            'status': o.skipped ? 'skipped' : o.draft.status.name,
            'overrides': o.overrides,
            'deleted': explicitDelete,
            'detached': o.detached,
            'completedAt': o.completedAt?.toUtc().toIso8601String(),
            if (o.terminal || o.detached) 'draft': o.draft.toJson(),
          },
        ),
      );
    }
    for (final mode in modes) {
      final id = mode['id'] as String;
      add(
        SyncRecord(
          kind: SyncKind.reminderConfig,
          id: id,
          data: {
            'taskId': parent(id),
            'mode': mode['mode'],
            'rules': [
              for (final r in reminderRules.where((r) => r.taskId == id))
                r.toJson()..remove('revision'),
            ],
          },
        ),
      );
    }
    if (validateRelations) {
      final categoryIds = categories.map((c) => c.id).toSet();
      final scopeIds = {...taskIds, ...ruleById.keys, ...occurrenceById.keys};
      if (scopeIds.length !=
          taskIds.length + ruleById.length + occurrenceById.length) {
        throw const AccountFailure(
          'invalid_relations',
          'Có mã dữ liệu trùng giữa công việc và lịch lặp.',
        );
      }
      for (final t in tasks) {
        if (t.categoryId != null && !categoryIds.contains(t.categoryId)) {
          throw const AccountFailure(
            'invalid_relations',
            'Danh mục của công việc chưa được tải đủ.',
          );
        }
      }
      for (final r in rules) {
        if (!taskIds.contains(r.taskId)) {
          throw const AccountFailure(
            'invalid_relations',
            'Chuỗi chưa có công việc gốc.',
          );
        }
        if (r.template.categoryId != null &&
            !categoryIds.contains(r.template.categoryId)) {
          throw const AccountFailure(
            'invalid_relations',
            'Danh mục trong mẫu chuỗi chưa được tải đủ.',
          );
        }
      }
      for (final o in occurrences) {
        if (!taskIds.contains(o.taskId) ||
            ruleById[o.ruleId]?.taskId != o.taskId) {
          throw const AccountFailure(
            'invalid_relations',
            'Lần lặp chưa có đủ mẫu chuỗi.',
          );
        }
        if (o.draft.categoryId != null &&
            !categoryIds.contains(o.draft.categoryId)) {
          throw const AccountFailure(
            'invalid_relations',
            'Danh mục của lần lặp chưa được tải đủ.',
          );
        }
      }
      for (final r in reminderRules) {
        if (!referenced.contains(r.taskId)) {
          throw const AccountFailure(
            'invalid_relations',
            'Mốc nhắc thiếu cấu hình công việc.',
          );
        }
        final mode = modes.firstWhere((m) => m['id'] == r.taskId)['mode'];
        if (mode == 'custom' &&
            r.enabled &&
            r.kind == ReminderKind.absolute &&
            !occurrenceById.containsKey(r.taskId) &&
            (ruleById.containsKey(r.taskId) ||
                rules.any((rule) => rule.taskId == r.taskId))) {
          throw const AccountFailure(
            'invalid_relations',
            'Chuỗi lặp cần dùng mốc nhắc tương đối; ngày giờ riêng chỉ áp dụng cho một lần.',
          );
        }
      }
    }
    return result;
  }

  Future<void> _bumpTask(String id) async {
    await db.customUpdate(
      'UPDATE tasks SET revision=revision+1 WHERE id=?',
      variables: [Variable<String>(id)],
      updates: {db.tasks},
    );
  }

  Future<void> apply(SyncRecord r) async {
    switch (r.kind) {
      case SyncKind.category:
        await db
            .into(db.categories)
            .insertOnConflictUpdate(
              CategoriesCompanion.insert(
                id: r.id,
                name: r.data['name'] as String,
                color: r.data['color'] as int,
              ),
            );
      case SyncKind.task:
        final old = await (db.select(
          db.tasks,
        )..where((t) => t.id.equals(r.id))).getSingleOrNull();
        final draft = domain.TaskDraft.fromJson(r.data);
        await db
            .into(db.tasks)
            .insertOnConflictUpdate(
              TasksCompanion.insert(
                id: r.id,
                title: draft.title,
                description: Value(draft.description),
                priority: draft.priority.index,
                status: draft.status.index,
                categoryId: Value(draft.categoryId),
                dueAt: Value(draft.dueAt),
                scheduledStartAt: Value(draft.scheduledStartAt),
                scheduledEndAt: Value(draft.scheduledEndAt),
                createdAt: validInstant(r.data['createdAt'], required: true)!,
                updatedAt: validInstant(r.data['updatedAt'], required: true)!,
                completedAt: Value(validInstant(r.data['completedAt'])),
                deletedAt: Value(validInstant(r.data['deletedAt'])),
                revision: Value((old?.revision ?? 0) + 1),
              ),
            );
      case SyncKind.recurrence:
        final existing = (await records.list('recurrence'))
            .where((j) => j['taskId'] == r.id)
            .toList();
        final incoming = (r.data['rules'] as List)
            .map((j) => (j as Map).cast<String, dynamic>())
            .toList();
        final ids = incoming.map((j) => j['id'] as String).toSet();
        for (final old in existing.where((j) => !ids.contains(j['id']))) {
          final archived = RecurrenceRule.fromJson(old).change(enabled: false);
          await records.put('recurrence', archived.id, archived.toJson());
        }
        for (final raw in incoming) {
          final old = existing.where((j) => j['id'] == raw['id']).firstOrNull;
          await records.put('recurrence', raw['id'] as String, {
            ...raw,
            'revision': (old?['revision'] as int? ?? 0) + 1,
          });
        }
        if (existing.isEmpty) {
          await _bumpTask(
            r.id,
          ); // invalidate a previous one-off alarm on conversion
        }
      case SyncKind.occurrence:
        final oldJson = await records.get('occurrences', r.id);
        final old = oldJson == null ? null : TaskOccurrence.fromJson(oldJson);
        final ruleJson = await records.get(
          'recurrence',
          r.data['ruleId'] as String,
        );
        if (ruleJson == null) {
          throw const AccountFailure(
            'invalid_relations',
            'Lần lặp thiếu mẫu chuỗi; chưa ghi đè dữ liệu.',
          );
        }
        final source = RecurrenceRule.fromJson(ruleJson);
        if (source.taskId != r.data['taskId']) {
          throw const AccountFailure(
            'invalid_relations',
            'Lần lặp không thuộc công việc này.',
          );
        }
        final generated = const RecurrenceGenerator().occurrence(
          source,
          r.data['date'] as String,
          clock(),
        );
        final status = r.deleted ? 'todo' : r.data['status'] as String;
        final detached = !r.deleted && r.data['detached'] == true;
        final terminal = ['completed', 'cancelled', 'skipped'].contains(status);
        final overrides = r.deleted
            ? <String, dynamic>{}
            : (r.data['overrides'] as Map).cast<String, dynamic>();
        final draft = terminal || detached
            ? domain.TaskDraft.fromJson((r.data['draft'] as Map).cast())
            : domain.TaskDraft.fromJson({
                ...generated.draft.toJson(),
                ...overrides,
                'status': status,
              });
        draft.validate();
        final next = TaskOccurrence(
          id: r.id,
          taskId: source.taskId,
          ruleId: source.id,
          date: generated.date,
          draft: draft,
          updatedAt: clock(),
          revision: (old?.revision ?? 0) + 1,
          completedAt: r.deleted ? null : validInstant(r.data['completedAt']),
          deleted: !r.deleted && r.data['deleted'] == true,
          skipped: status == 'skipped',
          detached: detached,
          overrides: overrides,
        );
        await records.put('occurrences', r.id, next.toJson());
      case SyncKind.reminderConfig:
        await _applyReminderConfig(r);
    }
  }

  Future<void> _applyReminderConfig(SyncRecord r) async {
    final root = r.data['taskId'] as String;
    final roots = (await repository.list()).map((t) => t.id).toSet();
    final rules = {
      for (final j in await records.list('recurrence')) j['id'] as String: j,
    };
    final occurrences = {
      for (final j in await records.list('occurrences')) j['id'] as String: j,
    };
    final scopeParent = roots.contains(r.id)
        ? r.id
        : rules[r.id]?['taskId'] ?? occurrences[r.id]?['taskId'];
    if (scopeParent != root) {
      throw const AccountFailure(
        'invalid_relations',
        'Cấu hình nhắc không thuộc công việc này.',
      );
    }
    final modes = {
      for (final j in await records.list('task_reminders'))
        j['id'] as String: j['mode'] as String,
    };
    final reminderRules = (await records.list('reminder_rules'))
        .map(ReminderRule.fromJson)
        .toList();
    String signature(String scope) {
      final parent = roots.contains(scope)
          ? scope
          : rules[scope]?['taskId'] ?? occurrences[scope]?['taskId'];
      final ids = {
        scope,
        if (occurrences[scope] != null) occurrences[scope]!['ruleId'] as String,
        if (parent != null) parent as String,
      };
      final selected = ids.where(modes.containsKey).firstOrNull;
      final mode = selected == null ? 'auto' : modes[selected]!;
      return canonicalJson({
        'mode': mode,
        if (mode == 'custom')
          'rules':
              reminderRules
                  .where((rule) => rule.taskId == selected && rule.enabled)
                  .map((rule) => rule.toJson()..remove('revision'))
                  .toList()
                ..sort(
                  (a, b) => (a['id'] as String).compareTo(b['id'] as String),
                ),
      });
    }

    final affected = occurrences.values
        .where(
          (o) =>
              o['taskId'] == root &&
              (r.id == root || o['ruleId'] == r.id || o['id'] == r.id),
        )
        .toList();
    final before = {
      for (final o in affected) o['id'] as String: signature(o['id'] as String),
    };
    final rootBefore = signature(root);
    final oldRules = reminderRules
        .where((rule) => rule.taskId == r.id)
        .toList();
    for (final rule in oldRules) {
      await records.remove('reminder_rules', rule.id);
    }
    reminderRules.removeWhere((rule) => rule.taskId == r.id);
    if (r.deleted) {
      await records.remove('task_reminders', r.id);
      modes.remove(r.id);
    } else {
      modes[r.id] = r.data['mode'] as String;
      await records.put('task_reminders', r.id, {
        'id': r.id,
        'mode': r.data['mode'],
      });
      for (final value in r.data['rules'] as List) {
        final j = (value as Map).cast<String, dynamic>();
        final id = j['id'] as String;
        final previous = oldRules.where((rule) => rule.id == id).firstOrNull;
        final next = ReminderRule.fromJson({
          ...j,
          'revision': (previous?.revision ?? 0) + 1,
        });
        reminderRules.add(next);
        await records.put('reminder_rules', id, next.toJson());
      }
    }
    for (final o in affected) {
      if (before[o['id']] != signature(o['id'] as String)) {
        final current = TaskOccurrence.fromJson(o);
        await records.put(
          'occurrences',
          current.id,
          current.copy(at: current.updatedAt).toJson(),
        );
      }
    }
    final recurring = rules.values.any((rule) => rule['taskId'] == root);
    if (!recurring && rootBefore != signature(root)) await _bumpTask(root);
  }

  Future<void> materialize() async {
    final service = RecurrenceService(repository, clock: clock);
    await service.materialize(await repository.list());
  }
}
