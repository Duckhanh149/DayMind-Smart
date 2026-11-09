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
  late String deviceZone;
  setUp(() async {
    now = DateTime.utc(2026, 1, 5);
    deviceZone = 'UTC';
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
      ReminderCoordinator(
        engine,
        controller.reminderTasks,
        readTimezone: () async => deviceZone,
      ),
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
  test('legacy inherited absolute rules never multiply across occurrences; one-instance absolute stays valid', () async {
    await engine.configureTask(rootId, 'custom', [
      ReminderRule(
        id: 'legacy-absolute',
        taskId: rootId,
        kind: ReminderKind.absolute,
        absoluteAt: DateTime.utc(2026, 1, 5, 8),
      ),
    ]);
    await controller.reminders!.refresh();
    expect(
      (await engine.events()).where((e) => e.state == 'scheduled'),
      isEmpty,
    );
    final selected = at(6);
    await engine.configureTask(selected.id, 'custom', [
      ReminderRule(
        id: 'own-absolute',
        taskId: selected.id,
        kind: ReminderKind.absolute,
        absoluteAt: DateTime.utc(2026, 1, 6, 8),
      ),
    ]);
    await controller.reminders!.refresh();
    final events = (await engine.events())
        .where((e) => e.state == 'scheduled')
        .toList();
    expect(events.length, 1);
    expect(events.single.occurrenceId, selected.id);
  });
  test('saved absolute rule rejects conversion to a series without losing the one-off task', () async {
    final id = await controller.save(
      TaskDraft(title: 'Một lần', dueAt: DateTime.utc(2026, 1, 5, 12)),
      notifications: TaskReminderConfig('custom', [
        ReminderRule(
          id: 'single-absolute',
          taskId: 'new',
          kind: ReminderKind.absolute,
          absoluteAt: DateTime.utc(2026, 1, 5, 11),
        ),
      ]),
    );
    final t = controller.tasks.singleWhere((t) => t.id == id);
    await expectLater(
      controller.save(
        TaskDraft.fromTask(t),
        existing: t,
        repetition: const RepeatChange(
          enabled: true,
          spec: RepeatSpec(
            frequency: RepeatFrequency.daily,
            firstDate: '2026-01-05',
            zone: 'UTC',
          ),
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
    await controller.load();
    expect(controller.recurrence.rules.any((r) => r.taskId == id), isFalse);
    expect(
      controller.tasks.singleWhere((t) => t.id == id).revision,
      t.revision,
    );
  });
  test(
    'stopping repetition keeps the selected edited task as a detached one-off',
    () async {
      final selected = at(6);
      await controller.save(
        renamed(selected, 'Việc cuối'),
        existing: selected,
        scope: EditScope.future,
        repetition: const RepeatChange(enabled: false),
      );
      expect(at(6).title, 'Việc cuối');
      expect(at(6).detached, isTrue);
      expect(
        controller.visibleTasks
            .where((t) => t.deletedAt == null)
            .map((t) => t.dueAt?.day)
            .toSet(),
        {5, 6},
      );
      await controller.load();
      expect(at(6).title, 'Việc cuối');
    },
  );
  test(
    'reopening completed history outside a stopped series remains visible',
    () async {
      await controller.toggle(at(8));
      await controller.delete(at(6), scope: EditScope.future);
      expect(at(8).status, TaskStatus.completed);
      await controller.toggle(at(8));
      expect(at(8).status, TaskStatus.todo);
      expect(at(8).detached, isTrue);
      await controller.load();
      expect(at(8).status, TaskStatus.todo);
    },
  );
  test('priority-only series edit preserves a selected title exception and another segment template', () async {
    await controller.save(
      renamed(at(7), 'Nhánh sau'),
      existing: at(7),
      scope: EditScope.future,
    );
    await controller.save(renamed(at(6), 'Ngoại lệ'), existing: at(6));
    final selected = at(6);
    await controller.save(
      TaskDraft.fromJson({
        ...TaskDraft.fromTask(selected).toJson(),
        'priority': 'high',
      }),
      existing: selected,
      scope: EditScope.all,
    );
    expect(at(5).title, 'Chuỗi gốc');
    expect(at(6).title, 'Ngoại lệ');
    expect(at(7).title, 'Nhánh sau');
    expect(at(8).title, 'Nhánh sau');
    expect(
      controller.visibleTasks.every((t) => t.priority == TaskPriority.high),
      isTrue,
    );
    expect(at(7).dueAt?.hour, 10);
  });
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
  test('travel updates quiet-hour zone during tray polling without changing the series zone', () async {
    await engine.configure(
      const NotificationPreferences(quietEnabled: true, timezoneId: 'UTC'),
    );
    await controller.reminders!.refresh();
    expect(
      (await engine.events()).where((e) => e.state == 'scheduled').length,
      4,
    );
    deviceZone = 'America/New_York';
    await controller.reminders!.refresh(replan: false);
    expect((await engine.preferences()).timezoneId, deviceZone);
    expect(
      (await engine.events()).where((e) => e.state == 'scheduled'),
      isEmpty,
    );
    expect(controller.recurrence.rules.single.spec.zone, 'UTC');
  });
  test('end-only schedule remains visible and can repeat without an invented start', () async {
    final id = await controller.save(
      TaskDraft(
        title: 'Chỉ đặt giờ kết thúc',
        scheduledEndAt: DateTime.utc(2026, 1, 5, 7),
      ),
      repetition: const RepeatChange(
        enabled: true,
        spec: RepeatSpec(
          frequency: RepeatFrequency.daily,
          firstDate: '2026-01-05',
          zone: 'UTC',
          count: 2,
        ),
      ),
    );
    final tasks = controller.visibleTasks
        .where((t) => t.seriesId == id)
        .toList();
    expect(tasks.length, 2);
    expect(tasks.every((t) => t.scheduledStartAt == null), isTrue);
    final entries = calendarEntries(tasks);
    expect(entries.length, 2);
    expect(entries.every((e) => e.kind == CalendarEntryKind.end), isTrue);
    expect(entries.map((e) => e.at.day).toSet(), {5, 6});
  });
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
