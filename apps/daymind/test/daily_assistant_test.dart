import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:daymind_smart/features/assistant/domain/daily_assistant.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/reminders/domain/reminder.dart';

void main() {
  zones.initializeTimeZones();
  final now = DateTime.utc(2026, 1, 5, 14);
  Task task(
    String id, {
    DateTime? due,
    DateTime? completed,
    TaskStatus status = TaskStatus.todo,
    bool deleted = false,
    String? category,
    String? series,
    TaskPriority priority = TaskPriority.medium,
  }) => Task(
    id: id,
    title: id,
    createdAt: DateTime.utc(2025),
    updatedAt: now,
    dueAt: due,
    completedAt: completed,
    status: status,
    deletedAt: deleted ? now : null,
    categoryId: category,
    seriesId: series,
    priority: priority,
  );
  test('metrics use explicit deadline/completion cohorts and exclude cancelled/trash', () {
    final tasks = [
      task(
        'on-time',
        due: DateTime.utc(2026, 1, 5, 10),
        completed: DateTime.utc(2026, 1, 5, 10),
        status: TaskStatus.completed,
        category: 'work',
      ),
      task(
        'late',
        due: DateTime.utc(2026, 1, 4, 10),
        completed: DateTime.utc(2026, 1, 5, 12),
        status: TaskStatus.completed,
      ),
      task(
        'no-deadline',
        completed: DateTime.utc(2026, 1, 5, 13),
        status: TaskStatus.completed,
      ),
      task('open', due: DateTime.utc(2026, 1, 5, 20)),
      task('overdue', due: DateTime.utc(2026, 1, 4, 13)),
      task('cancelled', due: now, completed: now, status: TaskStatus.cancelled),
      task(
        'deleted',
        due: now,
        completed: now,
        status: TaskStatus.completed,
        deleted: true,
      ),
      task('future', due: DateTime.utc(2026, 2)),
    ];
    final m = AnalyticsSnapshot.calculate(
      tasks,
      from: '2026-01-01',
      through: '2026-01-05',
      zone: 'UTC',
      now: now,
    );
    expect(m.completed, 3);
    expect(m.dueCount, 4);
    expect(m.dueCompleted, 2);
    expect(m.dueCompletionRate, .5);
    expect(m.withDeadline, 2);
    expect(m.onTime, 1);
    expect(m.onTimeRate, .5);
    expect(m.overdue, 1);
    expect(m.completionsByDay['2026-01-05'], 3);
    expect(m.completedByCategory, {'work': 1, '': 2});
    expect(DaySummary.calculate(tasks, now, 'UTC').open, 2);
  });
  test('empty/no-deadline data does not invent a percentage', () {
    final empty = AnalyticsSnapshot.calculate(
      [],
      from: '2026-01-05',
      through: '2026-01-05',
      zone: 'UTC',
      now: now,
    );
    expect(empty.dueCompletionRate, isNull);
    expect(empty.onTimeRate, isNull);
    expect(empty.completed, 0);
    final noDue = AnalyticsSnapshot.calculate(
      [task('done', completed: now, status: TaskStatus.completed)],
      from: '2026-01-05',
      through: '2026-01-05',
      zone: 'UTC',
      now: now,
    );
    expect(noDue.completed, 1);
    expect(noDue.onTimeRate, isNull);
    expect(noDue.dueCompletionRate, isNull);
  });
  test('completion day follows selected timezone including DST, not a fixed 24-hour window', () {
    final t = task(
      'boundary',
      completed: DateTime.utc(2026, 3, 9, 3, 30),
      status: TaskStatus.completed,
    );
    final m = AnalyticsSnapshot.calculate(
      [t],
      from: '2026-03-08',
      through: '2026-03-08',
      zone: 'America/New_York',
      now: now,
    );
    expect(m.completed, 1);
    expect(m.completionsByDay, {'2026-03-08': 1});
    expect(
      AnalyticsSnapshot.calculate(
        [t],
        from: '2026-03-08',
        through: '2026-03-08',
        zone: 'UTC',
        now: now,
      ).completed,
      0,
    );
  });
  test('suggestions are deterministic and contain at most one occurrence per series', () {
    final suggestions = suggestTasks(
      [
        task('older', due: DateTime.utc(2026, 1, 1), series: 'routine'),
        task('newer', due: DateTime.utc(2026, 1, 2), series: 'routine'),
        task('today', due: DateTime.utc(2026, 1, 5, 20)),
        task('priority', priority: TaskPriority.high),
        task('future', due: DateTime.utc(2026, 2), priority: TaskPriority.high),
        task('deleted', due: now, deleted: true),
      ],
      now,
      'UTC',
    );
    expect(suggestions.map((x) => x.task.id), ['older', 'today', 'priority']);
    expect(suggestions.first.reason, 'Đang quá hạn');
  });
  test('reopening removes a completion from current-state analytics', () {
    final t = task(
      'reopened',
      due: now,
      completed: now,
      status: TaskStatus.todo,
    );
    final m = AnalyticsSnapshot.calculate(
      [t],
      from: '2026-01-05',
      through: '2026-01-05',
      zone: 'UTC',
      now: now,
    );
    expect(m.completed, 0);
    expect(m.dueCompleted, 0);
  });
  test('dashboard stores an empty selection and drops unknown card IDs', () {
    expect(DashboardPreferences.fromJson({'cards': []}).cards, isEmpty);
    expect(
      DashboardPreferences.fromJson({
        'cards': ['today', 'unknown'],
      }).cards,
      {'today'},
    );
    expect(DashboardPreferences.fromJson(null).cards, contains('suggestions'));
  });
  test(
    'digest slots are opt-in, DST-aware and use one key per owner/local date',
    () {
      const policy = DailyDigestPolicy();
      final before = DateTime.utc(2026, 3, 8, 6);
      expect(
        policy.slots(const NotificationPreferences(), before, 'local'),
        isEmpty,
      );
      const prefs = NotificationPreferences(
        digestEnabled: true,
        digestMinute: 150,
        quietEnabled: false,
        timezoneId: 'America/New_York',
      );
      final slot = policy.slots(prefs, before, 'local').first;
      expect(slot.at, DateTime.utc(2026, 3, 8, 7));
      final edited = policy
          .slots(
            NotificationPreferences.fromJson({
              ...prefs.toJson(),
              'digestMinute': 240,
            }),
            before,
            'local',
          )
          .first;
      expect(edited.key, slot.key);
      expect(edited.at, isNot(slot.at));
      expect(policy.slots(prefs, before, 'other').first.key, isNot(slot.key));
      const quiet = NotificationPreferences(
        digestEnabled: true,
        digestMinute: 23 * 60,
      );
      expect(
        policy.slots(quiet, before, 'local').every((s) => s.suppressed),
        isTrue,
      );
    },
  );
}
