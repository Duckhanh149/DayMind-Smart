import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../tasks/domain/task.dart';
import '../../recurrence/domain/recurrence.dart';
import '../../reminders/domain/reminder.dart';

String localDay(DateTime instant, String zone) =>
    dateKey(tz.TZDateTime.from(instant, zoneLocation(zone)));
bool countable(Task t) =>
    t.deletedAt == null && t.status != TaskStatus.cancelled;

class DaySummary {
  const DaySummary(this.open, this.overdue, this.completed);
  final int open, overdue, completed;
  factory DaySummary.calculate(List<Task> tasks, DateTime now, String zone) {
    final day = localDay(now, zone);
    final visible = tasks.where(countable).toList();
    final late = visible.where((t) => t.overdue(now));
    final open = visible.where(
      (t) =>
          !t.terminal &&
          (t.overdue(now) ||
              [
                t.dueAt,
                t.scheduledStartAt,
                if (t.scheduledStartAt == null) t.scheduledEndAt,
              ].whereType<DateTime>().any((d) => localDay(d, zone) == day)),
    );
    final completed = visible.where(
      (t) =>
          t.status == TaskStatus.completed &&
          t.completedAt != null &&
          localDay(t.completedAt!, zone) == day,
    );
    return DaySummary(open.length, late.length, completed.length);
  }
  String get digest => 'Hôm nay: $open việc cần làm · $overdue quá hạn';
}

class Suggestion {
  const Suggestion(this.task, this.reason, this.score);
  final Task task;
  final String reason;
  final int score;
}

List<Suggestion> suggestTasks(List<Task> tasks, DateTime now, String zone) {
  final today = localDay(now, zone);
  final nextWeek = now.add(const Duration(days: 7));
  final scored = <Suggestion>[];
  for (final t in tasks.where((t) => countable(t) && !t.terminal)) {
    final scheduled = t.scheduledStartAt ?? t.scheduledEndAt;
    final late = t.overdue(now);
    final todayDue = t.dueAt != null && localDay(t.dueAt!, zone) == today;
    final todayStart = scheduled != null && localDay(scheduled, zone) == today;
    if (!late &&
        !todayDue &&
        !todayStart &&
        scheduled?.isAfter(nextWeek) == true) {
      continue;
    }
    if (!late && t.dueAt?.isAfter(nextWeek) == true && !todayStart) continue;
    final score =
        (late ? 100 : 0) +
        (todayDue ? 60 : 0) +
        (todayStart ? 30 : 0) +
        t.priority.index * 15 +
        (t.status == TaskStatus.inProgress ? 10 : 0);
    final reason = late
        ? 'Đang quá hạn'
        : todayDue
        ? 'Hạn trong hôm nay'
        : todayStart
        ? 'Có lịch thực hiện hôm nay'
        : t.status == TaskStatus.inProgress
        ? 'Bạn đang thực hiện'
        : t.priority == TaskPriority.high
        ? 'Bạn đã đặt ưu tiên cao'
        : t.dueAt == null && scheduled == null
        ? 'Chưa có lịch: chọn một bước nhỏ'
        : 'Có thể chuẩn bị trong tuần';
    scored.add(Suggestion(t, reason, score));
  }
  scored.sort((a, b) {
    final score = b.score.compareTo(a.score);
    if (score != 0) return score;
    final ad = a.task.dueAt ?? a.task.scheduledStartAt ?? a.task.createdAt,
        bd = b.task.dueAt ?? b.task.scheduledStartAt ?? b.task.createdAt;
    final date = ad.compareTo(bd);
    return date != 0 ? date : a.task.id.compareTo(b.task.id);
  });
  final series = <String>{};
  return scored
      .where((s) => series.add(s.task.seriesId ?? s.task.id))
      .take(3)
      .toList();
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.completed,
    required this.dueCount,
    required this.dueCompleted,
    required this.withDeadline,
    required this.onTime,
    required this.overdue,
    required this.completionsByDay,
    required this.completedByCategory,
  });
  final int completed, dueCount, dueCompleted, withDeadline, onTime, overdue;
  final Map<String, int> completionsByDay, completedByCategory;
  double? get dueCompletionRate =>
      dueCount == 0 ? null : dueCompleted / dueCount;
  double? get onTimeRate => withDeadline == 0 ? null : onTime / withDeadline;
  factory AnalyticsSnapshot.calculate(
    List<Task> tasks, {
    required String from,
    required String through,
    required String zone,
    required DateTime now,
  }) {
    civilDate(from);
    civilDate(through);
    if (from.compareTo(through) > 0) {
      throw const ValidationException('Khoảng thống kê không hợp lệ.');
    }
    bool inRange(DateTime? value) {
      if (value == null) return false;
      final day = localDay(value, zone);
      return day.compareTo(from) >= 0 && day.compareTo(through) <= 0;
    }

    final visible = tasks.where(countable).toList();
    final completed = visible
        .where(
          (t) => t.status == TaskStatus.completed && inRange(t.completedAt),
        )
        .toList();
    final due = visible.where((t) => inRange(t.dueAt)).toList();
    final withDeadline = completed.where((t) => t.dueAt != null).toList();
    final days = <String, int>{};
    for (var d = from; d.compareTo(through) <= 0; d = addDate(d, 1)) {
      days[d] = 0;
      if (days.length > 366) {
        throw const ValidationException('Mỗi lần thống kê tối đa một năm.');
      }
    }
    final categories = <String, int>{};
    for (final t in completed) {
      final day = localDay(t.completedAt!, zone);
      days[day] = (days[day] ?? 0) + 1;
      final category = t.categoryId ?? '';
      categories[category] = (categories[category] ?? 0) + 1;
    }
    return AnalyticsSnapshot(
      completed: completed.length,
      dueCount: due.length,
      dueCompleted: due.where((t) => t.status == TaskStatus.completed).length,
      withDeadline: withDeadline.length,
      onTime: withDeadline
          .where((t) => !t.completedAt!.isAfter(t.dueAt!))
          .length,
      overdue: visible.where((t) => t.overdue(now)).length,
      completionsByDay: days,
      completedByCategory: categories,
    );
  }
}

const dashboardCards = {
  'today': 'Cần làm hôm nay',
  'completed': 'Đã xong hôm nay',
  'overdue': 'Đang quá hạn',
  'high': 'Ưu tiên cao',
  'suggestions': 'Gợi ý tập trung',
};

class DashboardPreferences {
  const DashboardPreferences([
    this.cards = const {'today', 'completed', 'overdue', 'high', 'suggestions'},
  ]);
  final Set<String> cards;
  factory DashboardPreferences.fromJson(Map<String, dynamic>? j) =>
      j?['cards'] is List
      ? DashboardPreferences(
          (j!['cards'] as List)
              .whereType<String>()
              .where(dashboardCards.containsKey)
              .toSet(),
        )
      : const DashboardPreferences();
  Map<String, dynamic> toJson() => {'cards': cards.toList()..sort()};
}

class DigestSlot {
  const DigestSlot(
    this.date,
    this.taskId,
    this.key,
    this.at,
    this.expiresAt,
    this.suppressed,
  );
  final String date, taskId, key;
  final DateTime at, expiresAt;
  final bool suppressed;
}

class DailyDigestPolicy {
  const DailyDigestPolicy();
  List<DigestSlot> slots(
    NotificationPreferences prefs,
    DateTime now,
    String owner,
  ) {
    if (!prefs.digestEnabled) return [];
    final today = localDay(now, prefs.timezoneId), taskId = '__digest__:$owner';
    final result = <DigestSlot>[];
    for (var i = 0; i < 3; i++) {
      final day = addDate(today, i);
      var at = resolveWall(prefs.timezoneId, day, prefs.digestMinute);
      if (at == null) continue;
      DateTime? end;
      for (var n = 1; n <= 3 && end == null; n++) {
        end = resolveWall(prefs.timezoneId, addDate(day, n), 0);
      }
      if (end == null) continue;
      var suppressed = false;
      if (prefs.quietAt(at)) {
        final allowed = prefs.quietEndAfter(at);
        if (localDay(allowed, prefs.timezoneId) == day) {
          at = allowed;
        } else {
          suppressed = true;
        }
      }
      result.add(
        DigestSlot(
          day,
          taskId,
          sha256.convert(utf8.encode('$taskId|$day')).toString(),
          at,
          end,
          suppressed,
        ),
      );
    }
    return result;
  }
}
