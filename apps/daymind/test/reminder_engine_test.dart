import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/reminders/domain/reminder.dart';
import 'package:daymind_smart/features/reminders/application/reminder_engine.dart';

class FakeScheduler implements NotificationScheduler {
  bool permission = true, fail = false;
  final active = <int, DateTime>{};
  final cancelled = <int>[];
  int calls = 0;
  final shown = <({int id, String title, String body})>[];
  @override
  bool get supportsClosedApp => false;
  @override
  Future<bool> granted() async => permission;
  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<void> cancel(int id) async {
    active.remove(id);
    cancelled.add(id);
  }

  @override
  Future<void> schedule({
    required int id,
    required String eventKey,
    required DateTime at,
  }) async {
    calls++;
    if (fail) throw StateError('OS unavailable');
    active[id] = at;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? eventKey,
  }) async {
    shown.add((id: id, title: title, body: body));
  }
}

void main() {
  tzdata.initializeTimeZones();
  late DaymindDatabase db;
  late SqliteTaskRepository repo;
  late ReminderEngine engine;
  late FakeScheduler scheduler;
  late DateTime now;
  const policy = ReminderPolicy();
  const prefs = NotificationPreferences(timezoneId: 'Asia/Ho_Chi_Minh');
  setUp(() async {
    now = DateTime.utc(2026, 11, 9, 2);
    db = DaymindDatabase(NativeDatabase.memory());
    repo = SqliteTaskRepository(db, clock: () => now);
    scheduler = FakeScheduler();
    engine = ReminderEngine(db, scheduler, clock: () => now);
    await engine.configure(prefs);
  });
  tearDown(() => db.close());
  Task task({
    TaskPriority priority = TaskPriority.medium,
    DateTime? due,
    DateTime? start,
  }) => Task(
    id: 'test',
    title: 'Việc',
    priority: priority,
    dueAt: due,
    scheduledStartAt: start,
    createdAt: now,
    updatedAt: now,
  );
  Future<Task> create({
    DateTime? due,
    TaskPriority priority = TaskPriority.medium,
  }) async {
    final id = await repo.save(
      TaskDraft(
        title: 'Công việc',
        dueAt: due ?? now.add(const Duration(hours: 2)),
        priority: priority,
      ),
    );
    return (await repo.list()).singleWhere((t) => t.id == id);
  }

  Future<void> reconcile() async => engine.reconcile(await repo.list());
  test('NORMAL produces one reminder with high/medium/low offsets 30/15/0', () {
    for (final p in TaskPriority.values) {
      final t = task(priority: p, due: now.add(const Duration(hours: 2)));
      final rule = policy.defaultRule(t, prefs)!;
      expect(rule.offsetMinutes, [0, 15, 30][p.index]);
      expect(
        policy.plan(t, rule, prefs, now)!.at,
        t.dueAt!.subtract(Duration(minutes: rule.offsetMinutes)),
      );
    }
  });
  test('MINIMAL and no-deadline tasks have no implicit reminder', () {
    expect(policy.defaultRule(task(), prefs), isNull);
    expect(
      policy.defaultRule(
        task(due: now.add(const Duration(hours: 1))),
        const NotificationPreferences(preset: ReminderPreset.minimal),
      ),
      isNull,
    );
  });
  test(
    'CUSTOM default and explicit start/absolute anchors are independent',
    () {
      final t = task(
        due: now.add(const Duration(hours: 3)),
        start: now.add(const Duration(hours: 1)),
      );
      expect(
        policy
            .defaultRule(
              t,
              const NotificationPreferences(
                preset: ReminderPreset.custom,
                defaultOffsetMinutes: 7,
              ),
            )!
            .offsetMinutes,
        7,
      );
      expect(
        policy
            .plan(
              t,
              const ReminderRule(
                id: 'a',
                taskId: 'test',
                kind: ReminderKind.start,
                offsetMinutes: 10,
              ),
              prefs,
              now,
            )!
            .at,
        now.add(const Duration(minutes: 50)),
      );
      expect(
        policy
            .plan(
              t,
              ReminderRule(
                id: 'b',
                taskId: 'test',
                kind: ReminderKind.absolute,
                absoluteAt: now.add(const Duration(minutes: 20)),
              ),
              prefs,
              now,
            )!
            .at,
        now.add(const Duration(minutes: 20)),
      );
    },
  );
  test('new near-deadline task falls back once to future due, overdue never catches up', () {
    final t = task(due: now.add(const Duration(minutes: 5)));
    expect(
      policy.plan(t, policy.defaultRule(t, prefs)!, prefs, now)!.at,
      t.dueAt,
    );
    final old = task(due: now.subtract(const Duration(minutes: 1)));
    expect(
      policy.plan(old, policy.defaultRule(old, prefs)!, prefs, now),
      isNull,
    );
  });
  test('quiet hours cannot defer a stale 23:00 deadline into 07:00', () {
    final t = task(due: DateTime.utc(2026, 11, 9, 16));
    expect(
      policy.plan(t, policy.defaultRule(t, prefs)!, prefs, now)!.suppressed,
      isTrue,
    );
  });
  test('quiet boundary in the second DST fold stays on the same day', () {
    const local = NotificationPreferences(
      timezoneId: 'America/New_York',
      quietEnd: 90,
    );
    final trigger = DateTime.utc(2026, 11, 1, 6, 15);
    expect(local.quietEndAfter(trigger), DateTime.utc(2026, 11, 1, 6, 30));
    final t = task(due: DateTime.utc(2026, 11, 1, 6, 45));
    final plan = policy.plan(
      t,
      const ReminderRule(id: 'fold', taskId: 'test', offsetMinutes: 30),
      local,
      DateTime.utc(2026, 11, 1, 4),
    )!;
    expect(plan.at, DateTime.utc(2026, 11, 1, 6, 30));
    expect(plan.suppressed, isFalse);
  });
  test(
    'nonexistent DST quiet end uses first permitted instant before deadline',
    () {
      const local = NotificationPreferences(
        timezoneId: 'America/New_York',
        quietEnd: 150,
      );
      final trigger = DateTime.utc(2026, 3, 8, 6, 50);
      expect(local.quietEndAfter(trigger), DateTime.utc(2026, 3, 8, 7));
      final t = task(due: DateTime.utc(2026, 3, 8, 7, 15));
      final plan = policy.plan(
        t,
        const ReminderRule(id: 'gap', taskId: 'test', offsetMinutes: 25),
        local,
        DateTime.utc(2026, 3, 8, 6),
      )!;
      expect(plan.at, DateTime.utc(2026, 3, 8, 7));
      expect(plan.suppressed, isFalse);
    },
  );
  test('quiet hours defer to 07:00 only when deadline remains future', () {
    final t = task(due: DateTime.utc(2026, 11, 10, 0, 15));
    final plan = policy.plan(
      t,
      const ReminderRule(id: 'a', taskId: 'test', offsetMinutes: 495),
      prefs,
      now,
    )!;
    expect(plan.at, DateTime.utc(2026, 11, 10));
    expect(plan.suppressed, isFalse);
    expect(prefs.quietAt(DateTime.utc(2026, 11, 9, 15)), isTrue);
    expect(prefs.quietAt(DateTime.utc(2026, 11, 10)), isFalse);
  });
  test('invalid settings and rule sets fail without partially replacing old settings', () async {
    expect(
      () => const NotificationPreferences(
        quietStart: 420,
        quietEnd: 420,
      ).validate(),
      throwsA(isA<ValidationException>()),
    );
    final t = await create();
    await engine.configureTask(t.id, 'off', []);
    await expectLater(
      engine.configureTask(t.id, 'custom', [
        ReminderRule(id: 'bad', taskId: t.id, offsetMinutes: -1),
      ]),
      throwsA(isA<ValidationException>()),
    );
    expect((await engine.records.get('task_reminders', t.id))!['mode'], 'off');
  });
  test(
    'repeated reconcile schedules one id once and persists its key',
    () async {
      await create();
      await reconcile();
      await reconcile();
      await reconcile();
      expect((await engine.events()).length, 1);
      expect(scheduler.calls, 1);
      expect(scheduler.active.length, 1);
    },
  );
  test(
    'editing title invalidates old task revision and cancels old OS id',
    () async {
      final t = await create();
      await reconcile();
      final old = (await engine.events()).single;
      await repo.save(
        TaskDraft(title: 'Tên mới', dueAt: t.dueAt),
        id: t.id,
        expectedRevision: t.revision,
      );
      await reconcile();
      expect(scheduler.cancelled, contains(old.platformId));
      final events = await engine.events();
      expect(
        events.where((e) => e.state == 'scheduled').single.title,
        'Tên mới',
      );
      expect(
        events.singleWhere((e) => e.eventKey == old.eventKey).state,
        'cancelled',
      );
    },
  );
  test(
    'completion, cancellation and deletion each cancel pending reminders',
    () async {
      for (final operation in ['completed', 'cancelled', 'deleted']) {
        final t = await create();
        await reconcile();
        final old = (await engine.events()).firstWhere((e) => e.taskId == t.id);
        if (operation == 'deleted') {
          await repo.delete(t.id, t.revision);
        } else {
          await repo.save(
            TaskDraft(
              title: t.title,
              dueAt: t.dueAt,
              status: TaskStatus.values.byName(operation),
            ),
            id: t.id,
            expectedRevision: t.revision,
          );
        }
        await reconcile();
        expect(scheduler.active.containsKey(old.platformId), isFalse);
        expect(
          (await engine.events())
              .singleWhere((e) => e.eventKey == old.eventKey)
              .state,
          'cancelled',
        );
      }
    },
  );
  test(
    'switching to MINIMAL cancels an already scheduled automatic reminder',
    () async {
      await create();
      await reconcile();
      await engine.configure(
        const NotificationPreferences(preset: ReminderPreset.minimal),
      );
      await reconcile();
      expect(scheduler.active, isEmpty);
      expect((await engine.events()).single.state, 'cancelled');
    },
  );
  test(
    'per-task off cancels, custom replaces auto without two active alerts',
    () async {
      final t = await create();
      await reconcile();
      await engine.configureTask(t.id, 'custom', [
        ReminderRule(id: 'custom', taskId: t.id, offsetMinutes: 5),
      ]);
      await reconcile();
      expect(scheduler.active.length, 1);
      expect(
        (await engine.events())
            .singleWhere((e) => e.state == 'scheduled')
            .ruleId,
        'custom',
      );
      await engine.configureTask(t.id, 'off', []);
      await reconcile();
      expect(scheduler.active, isEmpty);
    },
  );
  test('quiet-hours changes cancel an existing OS schedule', () async {
    await create();
    await reconcile();
    await engine.configure(
      const NotificationPreferences(
        timezoneId: 'Asia/Ho_Chi_Minh',
        quietStart: 8 * 60,
        quietEnd: 12 * 60,
      ),
    );
    await reconcile();
    expect(scheduler.active, isEmpty);
    expect((await engine.events()).single.state, 'suppressed');
  });
  test(
    'permission denied then late grant does not create a second fallback',
    () async {
      scheduler.permission = false;
      await create();
      await reconcile();
      final original = (await engine.events()).single;
      now = DateTime.fromMillisecondsSinceEpoch(original.scheduledMs)
          .add(const Duration(minutes: 1));
      scheduler.permission = true;
      await reconcile();
      expect((await engine.events()).length, 1);
      expect(scheduler.active, isEmpty);
    },
  );
  test('revocation and secondary-device mode cancel schedules', () async {
    await create();
    await reconcile();
    scheduler.permission = false;
    await reconcile();
    expect(scheduler.active, isEmpty);
    scheduler.permission = true;
    await engine.configure(const NotificationPreferences(primaryDevice: false));
    await reconcile();
    expect(scheduler.active, isEmpty);
  });
  test('due claim is atomic and never replays the same event', () async {
    await create();
    await reconcile();
    now = DateTime.fromMillisecondsSinceEpoch(
      (await engine.events()).single.scheduledMs,
      isUtc: true,
    );
    final tasks = await repo.list();
    final claims = await Future.wait([
      engine.claimDue(tasks),
      engine.claimDue(tasks),
    ]);
    expect(claims.expand((x) => x).length, 1);
    expect((await engine.events()).single.state, 'unknown');
    expect(await engine.claimDue(tasks), isEmpty);
  });
  test(
    'foreground claim rechecks database revision even with stale task snapshot',
    () async {
      final t = await create();
      await reconcile();
      final snapshot = await repo.list();
      await repo.save(
        TaskDraft(title: t.title, status: TaskStatus.completed, dueAt: t.dueAt),
        id: t.id,
        expectedRevision: t.revision,
      );
      now = DateTime.fromMillisecondsSinceEpoch(
        (await engine.events()).single.scheduledMs,
        isUtc: true,
      );
      expect(await engine.claimDue(snapshot), isEmpty);
    },
  );
  test(
    'late wake expires instead of delivering an obsolete notification',
    () async {
      await create();
      await reconcile();
      now = now.add(const Duration(days: 1));
      expect(await engine.claimDue(await repo.list()), isEmpty);
      expect((await engine.events()).single.state, 'expired');
      await reconcile();
      expect(scheduler.calls, 1);
    },
  );
  test('dismiss is not completion, stale double snooze creates exactly one replacement', () async {
    final t = await create();
    await reconcile();
    final event = (await engine.events()).single;
    await Future.wait([
      engine.snooze(event, t, now.add(const Duration(minutes: 10))),
      engine.snooze(event, t, now.add(const Duration(minutes: 11))),
    ]);
    await reconcile();
    expect((await engine.events()).length, 2);
    expect(scheduler.active.length, 1);
    final replacement = (await engine.events()).singleWhere(
      (e) => e.state == 'scheduled',
    );
    await engine.dismiss(replacement);
    await reconcile();
    expect((await repo.list()).single.status, TaskStatus.todo);
    expect(scheduler.active, isEmpty);
  });
  test('failed OS scheduling stays planned and is retried without duplicate events', () async {
    scheduler.fail = true;
    await create();
    await reconcile();
    expect((await engine.events()).single.state, 'planned');
    scheduler.fail = false;
    await reconcile();
    expect((await engine.events()).length, 1);
    expect(scheduler.active.length, 1);
  });
  test(
    'bounded future window never arms more than 128 alarms after refills',
    () async {
      for (var i = 0; i < 135; i++) {
        await create(due: now.add(Duration(hours: 2, minutes: i)));
      }
      await reconcile();
      await reconcile();
      expect(scheduler.active.length, 128);
      await create(due: now.add(const Duration(hours: 1)));
      await reconcile();
      expect(scheduler.active.length, 128);
      expect(
        scheduler.active.values.firstWhere(
          (d) => d == now.add(const Duration(minutes: 45)),
        ),
        now.add(const Duration(minutes: 45)),
      );
    },
  );
  test(
    'importing 100 overdue tasks produces no events or OS scheduling',
    () async {
      for (var i = 0; i < 100; i++) {
        await create(due: now.subtract(Duration(days: i + 1)));
      }
      await reconcile();
      expect(await engine.events(), isEmpty);
      expect(scheduler.calls, 0);
    },
  );
}
