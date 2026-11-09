import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/record_store.dart';
import '../../tasks/data/database.dart';
import '../../tasks/domain/task.dart';
import '../domain/recurrence.dart';

class RepeatChange {
  const RepeatChange({required this.enabled, this.spec});
  final bool enabled;
  final RepeatSpec? spec;
}

class RecurrenceService {
  RecurrenceService(this.repository, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now,
      records = RecordStore(repository.db);
  final SqliteTaskRepository repository;
  final RecordStore records;
  final DateTime Function() clock;
  static const generator = RecurrenceGenerator();
  List<RecurrenceRule> rules = [];
  List<TaskOccurrence> occurrences = [];
  Set<String> get parentIds => rules.map((r) => r.taskId).toSet();
  RecurrenceRule? rule(String? id) =>
      rules.where((r) => r.id == id).firstOrNull;
  TaskOccurrence? occurrence(String? id) =>
      occurrences.where((r) => r.id == id).firstOrNull;
  Future<void> reload() async {
    rules = (await records.list('recurrence'))
        .map(RecurrenceRule.fromJson)
        .toList();
    occurrences = (await records.list('occurrences'))
        .map(TaskOccurrence.fromJson)
        .toList();
  }

  List<Task> project(List<Task> roots) {
    final byId = {for (final t in roots) t.id: t};
    return [
      for (final t in roots)
        if (!parentIds.contains(t.id) || t.deletedAt != null) t,
      for (final o in occurrences)
        if (!o.retired &&
            byId[o.taskId] != null &&
            byId[o.taskId]!.deletedAt == null)
          o.project(byId[o.taskId]!, ruleRevision: rule(o.ruleId)?.revision),
    ];
  }

  Future<void> materialize(
    List<Task> roots, {
    String? from,
    String? through,
  }) async {
    await reload();
    if (rules.isEmpty) return;
    await repository.db.transaction(() async {
      final old = {for (final o in occurrences) o.id: o};
      final terminalDates = {
        for (final o in occurrences.where((o) => o.terminal && !o.deleted))
          '${o.taskId}|${o.date}',
      };
      final existingRoots = {for (final t in roots) t.id: t};
      for (final r in rules.where((r) => r.enabled)) {
        final root = existingRoots[r.taskId];
        if (root == null || root.deletedAt != null || root.terminal) continue;
        final today = dateKey(
          tz.TZDateTime.from(clock(), zoneLocation(r.spec.zone)),
        );
        final begin = from ?? addDate(today, -35),
            end = through ?? addDate(today, 90);
        for (final date in generator.dates(r.spec, begin, end)) {
          if (r.activeFrom != null && date.compareTo(r.activeFrom!) < 0 ||
              r.cutoff != null && date.compareTo(r.cutoff!) > 0) {
            continue;
          }
          final generated = generator.occurrence(r, date, clock());
          final present = old[generated.id];
          if (present?.terminal == true || present?.detached == true) continue;
          if (present == null && terminalDates.contains('${r.taskId}|$date')) {
            continue;
          }
          if (present?.deleted == true && !present!.retired) {
            if (present.ruleId != r.id) {
              final next = present.copy(ruleId: r.id, at: clock());
              await records.put('occurrences', next.id, next.toJson());
              old[next.id] = next;
            }
            continue;
          }
          if (present == null) {
            await records.put('occurrences', generated.id, generated.toJson());
            continue;
          }
          final merged = TaskDraft.fromJson({
            ...generated.draft.toJson(),
            ...present.overrides,
            'status': present.draft.status.name,
          });
          merged.validate();
          if (jsonEncode(merged.toJson()) !=
                  jsonEncode(present.draft.toJson()) ||
              present.skipped != generated.skipped ||
              present.ruleId != r.id ||
              present.retired) {
            final next = TaskOccurrence(
              id: present.id,
              taskId: present.taskId,
              ruleId: r.id,
              date: present.date,
              draft: merged,
              updatedAt: clock(),
              revision: present.revision + 1,
              completedAt: present.completedAt,
              deleted: false,
              skipped: generated.skipped,
              overrides: present.overrides,
            );
            await records.put('occurrences', next.id, next.toJson());
            old[next.id] = next;
          }
        }
      }
      for (final o in old.values.where(
        (o) => !o.terminal && !o.deleted && !o.detached,
      )) {
        final r = rules.where((r) => r.id == o.ruleId).firstOrNull;
        final invalid =
            r == null ||
            !r.enabled ||
            r.activeFrom != null && o.date.compareTo(r.activeFrom!) < 0 ||
            r.cutoff != null && o.date.compareTo(r.cutoff!) > 0;
        final noLongerScheduled =
            !invalid &&
            o.overrides.isEmpty &&
            !generator.dates(r.spec, o.date, o.date).contains(o.date);
        if (invalid || noLongerScheduled) {
          await records.put(
            'occurrences',
            o.id,
            o.copy(deleted: true, retired: true, at: clock()).toJson(),
          );
        } else {
          final generated = generator.occurrence(r, o.date, clock());
          final merged = TaskDraft.fromJson({
            ...generated.draft.toJson(),
            ...o.overrides,
            'status': o.draft.status.name,
          });
          merged.validate();
          if (jsonEncode(merged.toJson()) != jsonEncode(o.draft.toJson())) {
            await records.put(
              'occurrences',
              o.id,
              o.copy(draft: merged, at: clock()).toJson(),
            );
          }
        }
      }
    });
    await reload();
  }

  Future<void> configure(
    String taskId,
    RepeatChange change,
    TaskDraft draft,
  ) async {
    await repository.db.transaction(() async {
      await reload();
      if (!change.enabled) {
        for (final r in rules.where((r) => r.taskId == taskId)) {
          await records.put(
            'recurrence',
            r.id,
            r.change(enabled: false).toJson(),
          );
        }
        return;
      }
      final spec = change.spec!;
      spec.validate();
      draft.validate();
      if ([TaskStatus.completed, TaskStatus.cancelled].contains(draft.status)) {
        throw const ValidationException(
          'Hãy tạo chuỗi ở trạng thái cần làm hoặc đang làm, rồi hoàn thành từng lần riêng.',
        );
      }
      final reference =
          draft.scheduledStartAt ?? draft.dueAt ?? draft.scheduledEndAt;
      final templateDate = reference == null
          ? spec.firstDate
          : dateKey(tz.TZDateTime.from(reference, zoneLocation(spec.zone)));
      final body = draft.toJson()..['status'] = 'todo';
      if (reference == null) {
        final first = resolveWall(spec.zone, spec.firstDate, spec.minute);
        if (first == null) {
          throw const ValidationException(
            'Ngày bắt đầu không tồn tại trong múi giờ này.',
          );
        }
        body['scheduledStartAt'] = first.toIso8601String();
      }
      for (final r in rules.where((r) => r.taskId == taskId)) {
        await records.put(
          'recurrence',
          r.id,
          r.change(enabled: false).toJson(),
        );
      }
      final rule = RecurrenceRule(
        id: const Uuid().v4(),
        taskId: taskId,
        spec: spec,
        template: TaskDraft.fromJson(body),
        templateDate: templateDate,
      );
      await records.put('recurrence', rule.id, rule.toJson());
    });
  }

  Future<TaskOccurrence> _current(Task selected) async {
    final json = await records.get(
      'occurrences',
      selected.occurrenceId ?? selected.id,
    );
    if (json == null) throw const EditConflict();
    final value = TaskOccurrence.fromJson(json);
    final root = await (repository.db.select(
      repository.db.tasks,
    )..where((t) => t.id.equals(value.taskId))).getSingleOrNull();
    if (root == null ||
        root.deletedAt != null ||
        root.revision != selected.seriesRevision) {
      throw const EditConflict();
    }
    if (value.revision != selected.revision || value.deleted) {
      throw const EditConflict();
    }
    return value;
  }

  Future<void> toggle(Task selected) => repository.db.transaction(() async {
    final value = await _current(selected);
    final completed = value.draft.status != TaskStatus.completed;
    final source = rule(value.ruleId);
    final outside =
        source == null ||
        !source.enabled ||
        source.activeFrom != null &&
            value.date.compareTo(source.activeFrom!) < 0 ||
        source.cutoff != null && value.date.compareTo(source.cutoff!) > 0 ||
        !generator
            .dates(source.spec, value.date, value.date)
            .contains(value.date);
    final draft = TaskDraft.fromJson({
      ...value.draft.toJson(),
      'status': completed ? 'completed' : 'todo',
    });
    final next = value.copy(
      draft: draft,
      detached: value.detached || (!completed && outside),
      completedAt: completed ? clock() : null,
      clearCompletion: !completed,
      at: clock(),
    );
    await records.put('occurrences', next.id, next.toJson());
  });
  Future<void> edit(
    Task selected,
    TaskDraft draft,
    EditScope scope, {
    RepeatChange? change,
  }) => repository.db.transaction(() async {
    final current = await _current(selected);
    draft.validate();
    await reload();
    final source = rule(current.ruleId);
    if (source == null) throw const EditConflict();
    if (scope != EditScope.one &&
        selected.recurrenceRevision != source.revision) {
      throw const EditConflict();
    }
    if (scope == EditScope.one) {
      if (change != null) {
        throw const ValidationException(
          'Để đổi lịch lặp, hãy chọn từ lần này hoặc toàn bộ chuỗi.',
        );
      }
      final overrides = {...current.overrides};
      final old = current.draft.toJson();
      for (final entry in draft.toJson().entries) {
        if (entry.key != 'status' && entry.value != old[entry.key]) {
          overrides[entry.key] = entry.value;
        }
      }
      final next = current.copy(
        draft: draft,
        overrides: overrides,
        completedAt: draft.status == TaskStatus.completed
            ? (current.completedAt ?? clock())
            : null,
        clearCompletion: draft.status != TaskStatus.completed,
        at: clock(),
      );
      await records.put('occurrences', next.id, next.toJson());
      return;
    }
    final before = current.draft.toJson();
    final changes = {
      for (final e in draft.toJson().entries)
        if (e.key != 'status' && e.value != before[e.key]) e.key: e.value,
    };
    TaskDraft templateFor(RecurrenceRule r) => TaskDraft.fromJson({
      ...generator.occurrence(r, current.date, clock()).draft.toJson(),
      ...changes,
      'status': 'todo',
    });
    if (scope == EditScope.future) {
      for (final r in rules.where((r) => r.taskId == current.taskId)) {
        if (r.activeFrom != null &&
            r.activeFrom!.compareTo(current.date) >= 0) {
          await records.put(
            'recurrence',
            r.id,
            r.change(enabled: false).toJson(),
          );
        } else if (r.cutoff == null || r.cutoff!.compareTo(current.date) >= 0) {
          await records.put(
            'recurrence',
            r.id,
            r.change(cutoff: addDate(current.date, -1)).toJson(),
          );
        }
      }
      if (change?.enabled != false) {
        final next = RecurrenceRule(
          id: const Uuid().v4(),
          taskId: current.taskId,
          spec: change?.spec ?? source.spec,
          template: templateFor(source),
          templateDate: current.date,
          activeFrom: current.date,
        );
        next.spec.validate();
        await records.put('recurrence', next.id, next.toJson());
      }
    } else {
      for (final r in rules.where((r) => r.taskId == current.taskId)) {
        RepeatSpec? spec;
        if (change?.spec != null) {
          final s = change!.spec!;
          spec = RepeatSpec(
            frequency: s.frequency,
            firstDate: s.firstDate == source.spec.firstDate
                ? r.spec.firstDate
                : s.firstDate,
            zone: s.zone,
            minute: s.minute,
            interval: s.interval,
            weekdays: s.weekdays,
            monthPolicy: s.monthPolicy,
            until: s.until,
            count: s.count,
          );
          spec.validate();
        }
        await records.put(
          'recurrence',
          r.id,
          r
              .change(
                template: templateFor(r),
                templateDate: current.date,
                spec: spec,
                enabled: change?.enabled == false ? false : r.enabled,
              )
              .toJson(),
        );
      }
    }
    if (change?.enabled == false) {
      final keep = current.copy(
        draft: draft,
        detached: true,
        at: clock(),
        completedAt: draft.status == TaskStatus.completed
            ? (current.completedAt ?? clock())
            : null,
        clearCompletion: draft.status != TaskStatus.completed,
      );
      await records.put('occurrences', keep.id, keep.toJson());
    } else {
      final overrides = {...current.overrides};
      if (![
        TaskStatus.completed,
        TaskStatus.cancelled,
      ].contains(draft.status)) {
        for (final e in changes.entries) {
          if (overrides.containsKey(e.key)) overrides[e.key] = e.value;
        }
      }
      if (draft.status != current.draft.status ||
          jsonEncode(overrides) != jsonEncode(current.overrides)) {
        final statusOnly = TaskDraft.fromJson({
          ...current.draft.toJson(),
          'status': draft.status.name,
        });
        await records.put(
          'occurrences',
          current.id,
          current
              .copy(
                draft: statusOnly,
                overrides: overrides,
                completedAt: draft.status == TaskStatus.completed
                    ? (current.completedAt ?? clock())
                    : null,
                clearCompletion: draft.status != TaskStatus.completed,
                at: clock(),
              )
              .toJson(),
        );
      }
    }
  });
  Future<void> remove(
    Task selected, {
    EditScope scope = EditScope.one,
  }) => repository.db.transaction(() async {
    final current = await _current(selected);
    if (scope == EditScope.one) {
      await records.put(
        'occurrences',
        current.id,
        current.copy(deleted: true, at: clock()).toJson(),
      );
      return;
    }
    await reload();
    if (rule(current.ruleId)?.revision != selected.recurrenceRevision) {
      throw const EditConflict();
    }
    if (scope == EditScope.all) {
      await repository.delete(current.taskId, selected.seriesRevision!);
      return;
    }
    for (final r in rules.where((r) => r.taskId == current.taskId)) {
      if (r.activeFrom != null && r.activeFrom!.compareTo(current.date) >= 0) {
        await records.put(
          'recurrence',
          r.id,
          r.change(enabled: false).toJson(),
        );
      } else if (r.cutoff == null || r.cutoff!.compareTo(current.date) >= 0) {
        await records.put(
          'recurrence',
          r.id,
          r.change(cutoff: addDate(current.date, -1)).toJson(),
        );
      }
    }
  });
  Future<void> restore(Task selected) => repository.db.transaction(() async {
    final json = await records.get(
      'occurrences',
      selected.occurrenceId ?? selected.id,
    );
    if (json == null) throw const EditConflict();
    final o = TaskOccurrence.fromJson(json);
    if (o.revision != selected.revision || !o.deleted) {
      throw const EditConflict();
    }
    await records.put(
      'occurrences',
      o.id,
      o.copy(deleted: false, at: clock()).toJson(),
    );
  });
}
