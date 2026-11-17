import 'package:daymind_smart/platform/ios_notification_scheduler.dart';
import 'package:daymind_smart/features/reminders/application/reminder_engine.dart';
import 'package:daymind_smart/features/reminders/application/reminder_coordinator.dart';
import 'package:daymind_smart/features/reminders/domain/reminder.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'reminder_engine_test.dart' show FakeScheduler;

class Backend implements IosNotificationBackend {
  bool permission = true, accept = true, initialized = true;
  final ids = <int>{};
  final instants = <int, DateTime>{};
  void Function(String, String)? response;
  @override
  Future<bool> initialize(void Function(String, String) callback) async {
    response = callback;
    return initialized;
  }

  @override
  Future<bool> granted() async => permission;
  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<Set<int>> pending() async => Set.of(ids);
  @override
  Future<void> schedule(int id, String key, DateTime at, String title) async {
    if (accept) {
      ids.add(id);
      instants[id] = at;
    }
  }

  @override
  Future<void> show(int id, String title, String body) async {}
  @override
  Future<void> cancel(int id) async {
    ids.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    ids.clear();
  }
}

class WindowScheduler extends FakeScheduler implements NotificationQueueWindow {
  @override
  bool get osOwnsDelivery => true;
  @override
  int get pendingLimit => 60;
  @override
  Future<Set<int>?> pendingIds() async => active.keys.toSet();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  final now = DateTime.utc(2026, 11, 17, 10);
  final key = 'a' * 64;
  late Backend backend;
  late IosNotificationAdapter adapter;
  setUp(() async {
    backend = Backend();
    adapter = IosNotificationAdapter(backend: backend, clock: () => now);
    adapter.resolveTitle = (_) async => 'private title';
    await adapter.initialize();
  });
  tearDown(() => adapter.deactivate());
  test(
    'OS ack is required; denied, past, missing content never succeed',
    () async {
      backend.accept = false;
      await expectLater(
        adapter.schedule(1, key, now.add(const Duration(minutes: 1))),
        throwsStateError,
      );
      expect(adapter.handedOff, isFalse);
      backend.accept = true;
      backend.permission = false;
      await expectLater(
        adapter.schedule(1, key, now.add(const Duration(minutes: 1))),
        throwsStateError,
      );
      backend.permission = true;
      await expectLater(adapter.schedule(1, key, now), throwsStateError);
      adapter.resolveTitle = (_) async => null;
      await expectLater(
        adapter.schedule(1, key, now.add(const Duration(minutes: 1))),
        throwsStateError,
      );
      expect(backend.ids, isEmpty);
    },
  );
  test('60 pending bound leaves OS reserve and same ID replaces, instant preserved', () async {
    for (var id = 1; id <= 60; id++) {
      await adapter.schedule(id, key, now.add(Duration(minutes: id)));
    }
    expect(adapter.handedOff, isTrue);
    await expectLater(
      adapter.schedule(61, key, now.add(const Duration(days: 1))),
      throwsStateError,
    );
    final instant = now.add(const Duration(hours: 3));
    await adapter.schedule(1, key, instant);
    expect(backend.ids.length, 60);
    expect(backend.instants[1], instant);
    await backend.cancel(2);
    await adapter.schedule(61, key, now.add(const Duration(days: 1)));
    expect(backend.ids.length, 60);
  });
  test(
    'cold callback waits for consumer; malformed or unrelated payload ignored',
    () async {
      backend.response!(key, 'snooze10');
      backend.response!('bad payload', 'open');
      backend.response!(key, 'bad action');
      final received = <String>[];
      adapter.onEvent = (key, action) async {
        received.add(action);
      };
      adapter.flush();
      await Future<void>.delayed(Duration.zero);
      expect(received, ['snooze10']);
      await adapter.deactivate();
      backend.response!(key, 'open');
      expect(received, ['snooze10']);
    },
  );
  test('failed initialization is never ready', () async {
    await adapter.deactivate();
    backend.initialized = false;
    await expectLater(adapter.initialize(), throwsStateError);
    expect(adapter.ready, isFalse);
  });
  test('engine shares 60 slots with digests; repairs missing/orphan OS entries; no past replay', () async {
    final db = DaymindDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var clock = now;
    final scheduler = WindowScheduler();
    final engine = ReminderEngine(db, scheduler, clock: () => clock);
    final repo = SqliteTaskRepository(db, clock: () => clock);
    await engine.configure(
      const NotificationPreferences(quietEnabled: false, digestEnabled: true),
    );
    for (var i = 0; i < 72; i++) {
      await repo.save(
        TaskDraft(
          title: 'Task $i',
          priority: TaskPriority.low,
          dueAt: now.add(Duration(minutes: 1 + i)),
        ),
      );
    }
    await engine.reconcile(await repo.list());
    expect(scheduler.active.length, 60);
    final originals = Map.of(scheduler.active);
    final removed = originals.keys.first;
    scheduler.active.remove(removed);
    scheduler.active[999999] = now.add(const Duration(days: 1));
    await engine.reconcile(await repo.list());
    expect(scheduler.active.length, 60);
    expect(scheduler.active.containsKey(removed), isTrue);
    expect(scheduler.active.containsKey(999999), isFalse);
    final calls = scheduler.calls;
    await engine.reconcile(await repo.list());
    expect(scheduler.calls, calls);
    clock = now.add(const Duration(minutes: 20));
    await engine.reconcile(await repo.list());
    expect(scheduler.active.values.every((at) => at.isAfter(clock)), isTrue);
    expect(
      (await engine.events())
          .where((e) => e.scheduledMs <= clock.millisecondsSinceEpoch)
          .every((e) => e.state != 'scheduled'),
      isTrue,
    );
    expect(scheduler.shown, isEmpty);
    scheduler.permission = false;
    await engine.reconcile(await repo.list());
    expect(scheduler.active, isEmpty);
  });
  test(
    'OS-owned coordinator never polls or redisplays old due events',
    () async {
      final db = DaymindDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var clock = now;
      final scheduler = WindowScheduler();
      final engine = ReminderEngine(db, scheduler, clock: () => clock);
      final repo = SqliteTaskRepository(db, clock: () => clock);
      await repo.save(
        TaskDraft(
          title: 'Due',
          priority: TaskPriority.low,
          dueAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await engine.configure(
        const NotificationPreferences(quietEnabled: false),
      );
      final coordinator = ReminderCoordinator(engine, repo.list);
      await coordinator.refresh();
      clock = now.add(const Duration(minutes: 2));
      await coordinator.refresh(replan: false);
      expect(scheduler.shown, isEmpty);
      expect((await engine.events()).single.state, 'scheduled');
      await coordinator.stop();
      coordinator.dispose();
    },
  );
  test('foreground cue is validated, deduplicated and snooze callback creates exactly one slot', () async {
    final db = DaymindDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var clock = now;
    final scheduler = WindowScheduler();
    final engine = ReminderEngine(db, scheduler, clock: () => clock);
    final repo = SqliteTaskRepository(db, clock: () => clock);
    await repo.save(
      TaskDraft(
        title: 'Due',
        priority: TaskPriority.low,
        dueAt: now.add(const Duration(minutes: 1)),
      ),
    );
    await engine.configure(const NotificationPreferences(quietEnabled: false));
    await engine.reconcile(await repo.list());
    final e = (await engine.events()).single;
    clock = now.add(const Duration(minutes: 1));
    expect(await engine.acceptOsForeground(e.eventKey), isNotNull);
    expect(await engine.acceptOsForeground(e.eventKey), isNull);
    final task = (await repo.list()).single;
    await engine.snooze(e, task, clock.add(const Duration(minutes: 10)));
    await engine.snooze(e, task, clock.add(const Duration(minutes: 11)));
    await engine.reconcile(await repo.list());
    expect(
      (await engine.events())
          .where((e) => e.ruleId.startsWith('snooze:'))
          .length,
      1,
    );
    expect(scheduler.active.length, 1);
  });
}
