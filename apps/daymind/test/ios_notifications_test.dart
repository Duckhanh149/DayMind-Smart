import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  Future<void> schedule(
    int id,
    String key,
    DateTime at,
    IosNotificationContent content,
  ) async {
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
    adapter.resolveContent = (_) async =>
        const IosNotificationContent('private title');
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
      adapter.resolveContent = (_) async => null;
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
  test('real Darwin transport serializes silent UTC categories and never asks on launch', () async {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' || 'requestPermissions' => true,
            'checkPermissions' => {'isEnabled': true, 'isAlertEnabled': false},
            'getNotificationAppLaunchDetails' => {
              'notificationLaunchedApp': false,
            },
            'pendingNotificationRequests' => <Map<String, Object>>[],
            _ => null,
          };
        });
    try {
      final native = DarwinNotificationBackend();
      expect(await native.initialize((_, _) {}), isTrue);
      expect(calls.any((c) => c.method == 'requestPermissions'), isFalse);
      final init =
          calls.firstWhere((c) => c.method == 'initialize').arguments as Map;
      for (final flag in [
        'requestAlertPermission',
        'requestSoundPermission',
        'requestBadgePermission',
        'requestProvisionalPermission',
        'requestCriticalPermission',
        'defaultPresentBanner',
        'defaultPresentList',
        'defaultPresentSound',
      ]) {
        expect(init[flag], false, reason: flag);
      }
      final categories = (init['notificationCategories'] as List).cast<Map>();
      final digest = categories.singleWhere(
        (x) => x['identifier'] == 'daymind.digest.v1',
      );
      expect(
        (digest['actions'] as List).cast<Map>().map((x) => x['identifier']),
        ['dismiss'],
      );
      expect(
        await native.granted(),
        isTrue,
      ); // Authorized center-only is not a banner claim.
      await native.requestPermission();
      final request =
          calls.lastWhere((c) => c.method == 'requestPermissions').arguments
              as Map;
      expect(request['alert'], true);
      expect(request['sound'], false);
      expect(request['critical'], false);
      final at = DateTime.now().toUtc().add(const Duration(days: 1));
      await native.schedule(
        42,
        key,
        at,
        const IosNotificationContent('Snapshot summary', digest: true),
      );
      final args =
          calls.lastWhere((c) => c.method == 'zonedSchedule').arguments as Map;
      expect(args['timeZoneName'], anyOf('UTC', 'Etc/UTC'));
      expect(args['payload'], key);
      expect(args['body'], 'Snapshot summary');
      final details = args['platformSpecifics'] as Map;
      expect(details['categoryIdentifier'], 'daymind.digest.v1');
      expect(details['threadIdentifier'], 'daymind.digests');
      expect(details['presentSound'], false);
      expect(details['presentBanner'], false);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
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
  test('iOS foreground digest reads current SQLite summary, not scheduled snapshot', () async {
    var clock = DateTime.utc(2026, 11, 17, 6, 59);
    final db = DaymindDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final scheduler = WindowScheduler();
    final engine = ReminderEngine(db, scheduler, clock: () => clock);
    final repo = SqliteTaskRepository(db, clock: () => clock);
    await engine.configure(
      const NotificationPreferences(
        preset: ReminderPreset.minimal,
        digestEnabled: true,
        quietEnabled: false,
      ),
    );
    await engine.reconcile([]);
    final event = (await engine.events())
        .where(
          (e) =>
              e.scheduledMs ==
              DateTime.utc(2026, 11, 17, 7).millisecondsSinceEpoch,
        )
        .single;
    await repo.save(
      TaskDraft(
        title: 'Added after scheduling',
        dueAt: DateTime.utc(2026, 11, 17, 8),
      ),
    );
    clock = DateTime.utc(2026, 11, 17, 7);
    await engine.reconcile(
      await repo.list(),
    ); // Resume may reconcile just before OS callback.
    final callbacks = await Future.wait([
      engine.acceptOsForeground(event.eventKey),
      engine.acceptOsForeground(event.eventKey),
    ]);
    expect(callbacks.whereType<ReminderEventRecord>().length, 1);
    final accepted = callbacks.whereType<ReminderEventRecord>().single;
    expect(accepted.title, contains('1 việc cần làm'));
    expect(await engine.acceptOsForeground(event.eventKey), isNull);
  });
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
