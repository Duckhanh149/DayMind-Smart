import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/features/calendar/domain/calendar.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/recurrence/domain/recurrence.dart';
import 'package:daymind_smart/features/recurrence/application/recurrence_service.dart';
import 'package:daymind_smart/features/reminders/application/reminder_engine.dart';
import 'package:daymind_smart/features/reminders/application/reminder_coordinator.dart';
import 'package:daymind_smart/features/reminders/domain/reminder.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';

import 'reminder_engine_test.dart' show FakeScheduler;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  zones.initializeTimeZones();
  late DaymindDatabase db;
  late WorkspaceController controller;
  late Directory temp;
  late ReminderEngine engine;
  late DateTime now;
  late String rootId;
  setUp(() async {
    now = DateTime.utc(2026, 1, 5);
    db = DaymindDatabase(NativeDatabase.memory());
    temp = Directory.systemTemp.createTempSync('daymind-recurrence-');
    controller = WorkspaceController(
      SqliteTaskRepository(db, clock: () => now),
      StaticAssetImporter(temp),
      clock: () => now,
    );
    await controller.load();
    engine = ReminderEngine(db, FakeScheduler(), clock: () => now);
    await engine.configure(const NotificationPreferences(quietEnabled: false));
    controller.attachReminders(
      ReminderCoordinator(engine, controller.reminderTasks),
    );
    rootId = await controller.save(
      TaskDraft(title: 'Chuỗi gốc', dueAt: DateTime.utc(2026, 1, 5, 10)),
      repetition: const RepeatChange(
        enabled: true,
        spec: RepeatSpec(
          frequency: RepeatFrequency.daily,
          firstDate: '2026-01-05',
          zone: 'UTC',
          count: 4,
        ),
      ),
    );
  });
  tearDown(() async {
    controller.dispose();
    await db.close();
    temp.deleteSync(recursive: true);
  });
  Task at(int day) => controller.visibleTasks.singleWhere(
    (t) => t.dueAt?.day == day && t.deletedAt == null,
  );
  TaskDraft renamed(Task t, String title) =>
      TaskDraft.fromJson({...TaskDraft.fromTask(t).toJson(), 'title': title});
  test(
    'four separate reminder slots; complete one cancels only that occurrence',
    () async {
      final before = await engine.events();
      expect(before.where((e) => e.state == 'scheduled').length, 4);
      expect(before.map((e) => e.occurrenceId).toSet().length, 4);
      expect(
        before.every(
          (e) =>
              e.taskId == rootId &&
              e.taskRevision == 1 &&
              e.occurrenceRevision == 1,
        ),
        isTrue,
      );
      final first = at(5);
      await controller.toggle(first);
      final after = await engine.events();
      expect(
        after.singleWhere((e) => e.occurrenceId == first.id).state,
        'cancelled',
      );
      expect(after.where((e) => e.state == 'scheduled').length, 3);
      expect(controller.tasks.single.status, TaskStatus.todo);
    },
  );
  test(
    'future split keeps IDs, future exceptions and explicit deleted dates',
    () async {
      final day8 = at(8), day7 = at(7);
      await controller.save(renamed(day8, 'Ngoại lệ ngày 8'), existing: day8);
      await controller.delete(day7);
      final chosen = at(6);
      await controller.save(
        renamed(chosen, 'Từ ngày 6'),
        existing: chosen,
        scope: EditScope.future,
      );
      expect(at(5).title, 'Chuỗi gốc');
      expect(at(6).title, 'Từ ngày 6');
      expect(at(8).id, day8.id);
      expect(at(8).title, 'Ngoại lệ ngày 8');
      expect(
        controller.visibleTasks.where(
          (t) => t.deletedAt == null && t.dueAt?.day == 7,
        ),
        isEmpty,
      );
      final deleted = controller.visibleTasks.singleWhere(
        (t) => t.id == day7.id,
      );
      await controller.restore(deleted);
      expect(at(7).title, 'Từ ngày 6');
      expect(
        controller.visibleTasks.map((t) => t.id).toSet().length,
        controller.visibleTasks.length,
      );
    },
  );
  test(
    'all-series removal and root restore retain history and future slots',
    () async {
      await controller.toggle(at(5));
      await controller.delete(at(6), scope: EditScope.all);
      expect(controller.visibleTasks.single.deletedAt, isNotNull);
      await controller.restore(controller.visibleTasks.single);
      expect(at(5).status, TaskStatus.completed);
      expect(at(6).status, TaskStatus.todo);
      expect(
        (await engine.events()).where((e) => e.state == 'scheduled').length,
        3,
      );
    },
  );
  test(
    'one-instance notification off leaves the other three alarms scheduled',
    () async {
      final chosen = at(6);
      await controller.save(
        TaskDraft.fromTask(chosen),
        existing: chosen,
        notifications: const TaskReminderConfig('off', []),
      );
      final events = await engine.events();
      expect(
        events.where(
          (e) => e.occurrenceId == chosen.id && e.state == 'scheduled',
        ),
        isEmpty,
      );
      expect(events.where((e) => e.state == 'scheduled').length, 3);
    },
  );
  test('relative custom rules inherited by series; future override has its own scope', () async {
    final chosen = at(6);
    const config = TaskReminderConfig('custom', [
      ReminderRule(
        id: 'my-rule',
        taskId: 'new',
        kind: ReminderKind.due,
        offsetMinutes: 60,
      ),
    ]);
    await controller.save(
      TaskDraft.fromTask(chosen),
      existing: chosen,
      scope: EditScope.future,
      notifications: config,
    );
    final scheduled = (await engine.events())
        .where((e) => e.state == 'scheduled')
        .toList();
    expect(scheduled.length, 4);
    expect(
      scheduled.singleWhere((e) => e.occurrenceId == at(5).id).ruleId,
      'default',
    );
    expect(
      scheduled
          .where((e) => e.occurrenceId != at(5).id)
          .every((e) => e.ruleId != 'default'),
      isTrue,
    );
  });
  test(
    'fresh SQLite occurrence status prevents delivery from stale UI snapshot',
    () async {
      final stale = controller.visibleTasks;
      final first = at(5), o = controller.recurrence.occurrence(first.id)!;
      await controller.recurrence.records.put('occurrences', o.id, {
        ...o.toJson(),
        'status': 'completed',
        'revision': o.revision + 1,
      });
      now = DateTime.utc(2026, 1, 5, 9, 45);
      expect(await engine.claimDue(stale), isEmpty);
      expect(
        (await engine.events())
            .singleWhere((e) => e.occurrenceId == first.id)
            .state,
        'cancelled',
      );
      await controller.refreshFromNative();
      expect(at(5).status, TaskStatus.completed);
    },
  );
  test(
    'reloading persisted rules does not duplicate occurrences or reminders',
    () async {
      final ids = controller.visibleTasks.map((t) => t.id).toSet();
      await controller.load();
      await controller.reminders!.refresh();
      expect(controller.visibleTasks.map((t) => t.id).toSet(), ids);
      expect((await engine.events()).length, 4);
    },
  );
  test(
    'absolute reminder on a new series rolls back task and recurrence together',
    () async {
      final count = controller.tasks.length;
      await expectLater(
        controller.save(
          const TaskDraft(title: 'Không hợp lệ'),
          repetition: const RepeatChange(
            enabled: true,
            spec: RepeatSpec(
              frequency: RepeatFrequency.daily,
              firstDate: '2026-01-05',
              zone: 'UTC',
            ),
          ),
          notifications: TaskReminderConfig('custom', [
            ReminderRule(
              id: 'absolute',
              taskId: 'new',
              kind: ReminderKind.absolute,
              absoluteAt: now.add(const Duration(hours: 2)),
            ),
          ]),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect((await controller.repository.list()).length, count);
    },
  );
  test('calendar separates schedule and deadline and marks actual interval overlaps', () {
    Task make(String id, int hour, int end) => Task(
      id: id,
      title: id,
      createdAt: now,
      updatedAt: now,
      scheduledStartAt: DateTime.utc(2026, 1, 5, hour),
      scheduledEndAt: DateTime.utc(2026, 1, 5, end),
      dueAt: DateTime.utc(2026, 1, 6),
    );
    final entries = calendarEntries([
      make('a', 9, 11),
      make('b', 10, 12),
      make('c', 12, 13),
    ]);
    expect(entries.length, 6);
    expect(overlappingTasks(entries), {'a', 'b'});
    expect(
      entries
          .where((e) => e.occursOn('2026-01-06', 'UTC'))
          .every((e) => e.kind == CalendarEntryKind.deadline),
      isTrue,
    );
    expect(
      entries
          .where((e) => e.occursOn('2026-01-05', 'UTC'))
          .every((e) => e.kind == CalendarEntryKind.scheduled),
      isTrue,
    );
  });
}
