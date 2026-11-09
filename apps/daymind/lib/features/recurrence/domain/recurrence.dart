import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../tasks/domain/task.dart';

enum RepeatFrequency { daily, weekly, monthly }

enum MonthDayPolicy { skip, lastDay }

enum EditScope { one, future, all }

tz.Location zoneLocation(String id) =>
    id == 'UTC' ? tz.UTC : tz.getLocation(id);
String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime civilDate(String key) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
    throw const ValidationException('Ngày lặp không hợp lệ.');
  }
  final d = DateTime.parse('${key}T00:00:00Z');
  if (dateKey(d) != key || d.year < 2000 || d.year > 2100) {
    throw const ValidationException('Ngày lặp cần trong khoảng 2000–2100.');
  }
  return d;
}

String addDate(String key, int days) =>
    dateKey(civilDate(key).add(Duration(days: days)));

/// Both fold instants, ordered earliest first. No OS-local timezone dependency.
List<DateTime> wallCandidates(String zone, String date, int minute) {
  final loc = zoneLocation(zone), day = civilDate(date);
  final naive = DateTime.utc(day.year, day.month, day.day, 0, minute);
  final offsets = <int>{};
  for (var h = -48; h <= 48; h += 6) {
    offsets.add(
      loc
          .timeZone(naive.add(Duration(hours: h)).millisecondsSinceEpoch)
          .offset
          .inMilliseconds,
    );
  }
  final result = <DateTime>[];
  for (final offset in offsets) {
    final candidate = naive.subtract(Duration(milliseconds: offset));
    final local = tz.TZDateTime.from(candidate, loc);
    if (local.year == naive.year &&
        local.month == naive.month &&
        local.day == naive.day &&
        local.hour == naive.hour &&
        local.minute == naive.minute) {
      result.add(candidate);
    }
  }
  return result..sort();
}

/// First fold; a gap moves to the next valid wall minute, up to three hours.
/// An entirely missing civil date is recorded as skipped by the generator.
DateTime? resolveWall(String zone, String date, int minute) {
  final day = civilDate(date);
  for (var delta = 0; delta <= 180; delta++) {
    final local = DateTime.utc(day.year, day.month, day.day, 0, minute + delta);
    final candidates = wallCandidates(
      zone,
      dateKey(local),
      local.hour * 60 + local.minute,
    );
    if (candidates.isNotEmpty) return candidates.first;
  }
  return null;
}

class RepeatSpec {
  const RepeatSpec({
    required this.frequency,
    required this.firstDate,
    required this.zone,
    this.minute = 9 * 60,
    this.interval = 1,
    this.weekdays = const [],
    this.monthPolicy,
    this.until,
    this.count,
  });
  final RepeatFrequency frequency;
  final String firstDate, zone;
  final int minute, interval;
  final List<int> weekdays;
  final MonthDayPolicy? monthPolicy;
  final String? until;
  final int? count;
  void validate() {
    civilDate(firstDate);
    zoneLocation(zone);
    if (minute < 0 ||
        minute > 1439 ||
        interval < 1 ||
        interval > 365 ||
        count != null && (count! < 1 || count! > 10000)) {
      throw const ValidationException('Khoảng lặp hoặc số lần không hợp lệ.');
    }
    if (frequency == RepeatFrequency.weekly &&
        (weekdays.isEmpty || weekdays.any((d) => d < 1 || d > 7))) {
      throw const ValidationException('Hãy chọn ít nhất một ngày trong tuần.');
    }
    if (frequency == RepeatFrequency.monthly && monthPolicy == null) {
      throw const ValidationException('Hãy chọn cách xử lý tháng thiếu ngày.');
    }
    if (until != null && civilDate(until!).isBefore(civilDate(firstDate))) {
      throw const ValidationException(
        'Ngày kết thúc phải từ ngày bắt đầu trở đi.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'frequency': frequency.name,
    'firstDate': firstDate,
    'zone': zone,
    'minute': minute,
    'interval': interval,
    'weekdays': weekdays,
    'monthPolicy': monthPolicy?.name,
    'until': until,
    'count': count,
  };
  factory RepeatSpec.fromJson(Map<String, dynamic> j) => RepeatSpec(
    frequency: RepeatFrequency.values.byName(j['frequency'] as String),
    firstDate: j['firstDate'] as String,
    zone: j['zone'] as String,
    minute: j['minute'] as int? ?? 540,
    interval: j['interval'] as int? ?? 1,
    weekdays: (j['weekdays'] as List? ?? []).cast<int>(),
    monthPolicy: j['monthPolicy'] == null
        ? null
        : MonthDayPolicy.values.byName(j['monthPolicy'] as String),
    until: j['until'] as String?,
    count: j['count'] as int?,
  );
}

class RecurrenceRule {
  const RecurrenceRule({
    required this.id,
    required this.taskId,
    required this.spec,
    required this.template,
    required this.templateDate,
    this.activeFrom,
    this.cutoff,
    this.enabled = true,
    this.revision = 1,
  });
  final String id, taskId, templateDate;
  final RepeatSpec spec;
  final TaskDraft template;
  final String? activeFrom, cutoff;
  final bool enabled;
  final int revision;
  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'spec': spec.toJson(),
    'template': template.toJson(),
    'templateDate': templateDate,
    'activeFrom': activeFrom,
    'cutoff': cutoff,
    'enabled': enabled,
    'revision': revision,
  };
  factory RecurrenceRule.fromJson(Map<String, dynamic> j) => RecurrenceRule(
    id: j['id'] as String,
    taskId: j['taskId'] as String,
    spec: RepeatSpec.fromJson((j['spec'] as Map).cast()),
    template: TaskDraft.fromJson((j['template'] as Map).cast()),
    templateDate: j['templateDate'] as String,
    activeFrom: j['activeFrom'] as String?,
    cutoff: j['cutoff'] as String?,
    enabled: j['enabled'] != false,
    revision: j['revision'] as int? ?? 1,
  );
  RecurrenceRule change({
    TaskDraft? template,
    String? templateDate,
    RepeatSpec? spec,
    String? cutoff,
    bool? enabled,
  }) => RecurrenceRule(
    id: id,
    taskId: taskId,
    spec: spec ?? this.spec,
    template: template ?? this.template,
    templateDate: templateDate ?? this.templateDate,
    activeFrom: activeFrom,
    cutoff: cutoff ?? this.cutoff,
    enabled: enabled ?? this.enabled,
    revision: revision + 1,
  );
}

class TaskOccurrence {
  const TaskOccurrence({
    required this.id,
    required this.taskId,
    required this.ruleId,
    required this.date,
    required this.draft,
    required this.updatedAt,
    this.revision = 1,
    this.completedAt,
    this.deleted = false,
    this.skipped = false,
    this.retired = false,
    this.detached = false,
    this.overrides = const {},
  });
  final String id, taskId, ruleId, date;
  final TaskDraft draft;
  final DateTime updatedAt;
  final int revision;
  final DateTime? completedAt;
  final bool deleted, skipped, retired, detached;
  final Map<String, dynamic> overrides;
  bool get terminal =>
      skipped ||
      draft.status == TaskStatus.completed ||
      draft.status == TaskStatus.cancelled;
  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'ruleId': ruleId,
    'date': date,
    'draft': draft.toJson(),
    'status': skipped ? 'skipped' : draft.status.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'deleted': deleted,
    'skipped': skipped,
    'retired': retired,
    'detached': detached,
    'overrides': overrides,
  };
  factory TaskOccurrence.fromJson(Map<String, dynamic> j) {
    final data = (j['draft'] as Map).cast<String, dynamic>();
    // Native notification actions store occurrence status outside the snapshot.
    if (j['status'] != null && j['status'] != 'skipped') {
      data['status'] = j['status'];
    }
    return TaskOccurrence(
      id: j['id'] as String,
      taskId: j['taskId'] as String,
      ruleId: j['ruleId'] as String,
      date: j['date'] as String,
      draft: TaskDraft.fromJson(data),
      updatedAt: readInstant(j['updatedAt'])!,
      revision: j['revision'] as int? ?? 1,
      completedAt: readInstant(j['completedAt']),
      deleted: j['deleted'] == true,
      skipped: j['skipped'] == true || j['status'] == 'skipped',
      retired: j['retired'] == true,
      detached: j['detached'] == true,
      overrides: (j['overrides'] as Map? ?? {}).cast(),
    );
  }
  TaskOccurrence copy({
    TaskDraft? draft,
    DateTime? completedAt,
    bool clearCompletion = false,
    bool? deleted,
    bool? retired,
    bool? detached,
    String? ruleId,
    Map<String, dynamic>? overrides,
    DateTime? at,
  }) => TaskOccurrence(
    id: id,
    taskId: taskId,
    ruleId: ruleId ?? this.ruleId,
    date: date,
    draft: draft ?? this.draft,
    updatedAt: at ?? updatedAt,
    revision: revision + 1,
    completedAt: clearCompletion ? null : completedAt ?? this.completedAt,
    deleted: deleted ?? this.deleted,
    skipped: skipped,
    retired: retired ?? this.retired,
    detached: detached ?? this.detached,
    overrides: overrides ?? this.overrides,
  );
  Task project(Task root, {int? ruleRevision}) => Task(
    id: id,
    seriesId: taskId,
    occurrenceId: id,
    recurrenceRuleId: ruleId,
    recurrenceRevision: ruleRevision,
    seriesRevision: root.revision,
    detached: detached,
    title: draft.title,
    description: draft.description,
    categoryId: draft.categoryId,
    priority: draft.priority,
    status: skipped ? TaskStatus.cancelled : draft.status,
    dueAt: draft.dueAt,
    scheduledStartAt: draft.scheduledStartAt,
    scheduledEndAt: draft.scheduledEndAt,
    createdAt: root.createdAt,
    updatedAt: updatedAt,
    completedAt: completedAt,
    deletedAt: deleted ? updatedAt : root.deletedAt,
    revision: revision,
  );
}

class RecurrenceGenerator {
  const RecurrenceGenerator();
  List<String> dates(RepeatSpec spec, String from, String through) {
    spec.validate();
    final first = civilDate(spec.firstDate),
        last = civilDate(through),
        rangeStart = civilDate(from);
    if (last.difference(rangeStart).inDays > 1100) {
      throw const ValidationException('Mỗi lần xem tối đa ba năm lịch.');
    }
    final result = <String>[];
    var generated = 0;
    final weekAnchor = first.subtract(Duration(days: first.weekday - 1));
    for (
      var date = first;
      !date.isAfter(last);
      date = date.add(const Duration(days: 1))
    ) {
      final key = dateKey(date);
      if (spec.until != null && key.compareTo(spec.until!) > 0) break;
      final months = (date.year - first.year) * 12 + date.month - first.month;
      final daysInMonth = DateTime.utc(date.year, date.month + 1, 0).day;
      final monthlyDay =
          spec.monthPolicy == MonthDayPolicy.lastDay && first.day > daysInMonth
          ? daysInMonth
          : first.day;
      final matches = switch (spec.frequency) {
        RepeatFrequency.daily =>
          date.difference(first).inDays % spec.interval == 0,
        RepeatFrequency.weekly =>
          date.difference(weekAnchor).inDays ~/ 7 % spec.interval == 0 &&
              spec.weekdays.contains(date.weekday),
        RepeatFrequency.monthly =>
          months % spec.interval == 0 && date.day == monthlyDay,
      };
      if (!matches) continue;
      generated++;
      if (spec.count != null && generated > spec.count!) break;
      if (!date.isBefore(rangeStart)) result.add(key);
    }
    return result;
  }

  TaskOccurrence occurrence(RecurrenceRule rule, String date, DateTime now) {
    DateTime? shift(DateTime? instant) {
      if (instant == null) return null;
      final local = tz.TZDateTime.from(instant, zoneLocation(rule.spec.zone));
      final delta = civilDate(dateKey(local))
          .difference(civilDate(rule.templateDate))
          .inDays;
      return resolveWall(
        rule.spec.zone,
        addDate(date, delta),
        local.hour * 60 + local.minute,
      );
    }

    final anchor = resolveWall(rule.spec.zone, date, rule.spec.minute);
    final start = shift(rule.template.scheduledStartAt),
        due = shift(rule.template.dueAt);
    final duration =
        rule.template.scheduledStartAt != null &&
            rule.template.scheduledEndAt != null
        ? rule.template.scheduledEndAt!.difference(
            rule.template.scheduledStartAt!,
          )
        : null;
    final end = duration != null && start != null
        ? start.add(duration)
        : shift(rule.template.scheduledEndAt);
    final draft = TaskDraft(
      title: rule.template.title,
      description: rule.template.description,
      priority: rule.template.priority,
      categoryId: rule.template.categoryId,
      scheduledStartAt: start,
      scheduledEndAt: end,
      dueAt: due,
    );
    draft.validate();
    return TaskOccurrence(
      id: sha256.convert(utf8.encode('${rule.taskId}|$date')).toString(),
      taskId: rule.taskId,
      ruleId: rule.id,
      date: date,
      draft: draft,
      updatedAt: now,
      skipped: anchor == null,
    );
  }
}
