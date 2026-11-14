import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/reminders/domain/reminder.dart';
import 'package:daymind_smart/features/reminders/application/reminder_engine.dart';

import 'reminder_engine_test.dart' show FakeScheduler;

void main() {
  zones.initializeTimeZones();
  late DaymindDatabase db;
  late SqliteTaskRepository repo;
  late ReminderEngine engine;
  late FakeScheduler scheduler;
  late DateTime now;
  setUp(() async {
    now = DateTime.utc(2026, 1, 5);
    db = DaymindDatabase(NativeDatabase.memory());
    repo = SqliteTaskRepository(db, clock: () => now);
    scheduler = FakeScheduler();
    engine = ReminderEngine(db, scheduler, clock: () => now);
  });
  tearDown(() => db.close());
  Future<void> configure(Map<String, dynamic> changes) async {
    final old = await engine.preferences();
    await engine.configure(
      NotificationPreferences.fromJson({...old.toJson(), ...changes}),
    );
    await engine.reconcile(await repo.list());
  }

  test(
    'default creates no digest; opt-in creates three future daily slots',
    () async {
      await engine.reconcile([]);
      expect(await engine.events(), isEmpty);
      await configure({'digestEnabled': true});
      final e = await engine.events();
      expect(e.length, 3);
      expect(
        e.every((x) => x.ruleId == 'digest' && x.state == 'scheduled'),
        isTrue,
      );
      await engine.reconcile([]);
      expect((await engine.events()).length, 3);
    },
  );
  test(
    'one per date even after time edits, restart and permission changes',
    () async {
      await configure({'digestEnabled': true});
      now = DateTime.utc(2026, 1, 5, 7);
      final shown = await engine.claimDue([]);
      expect(shown.length, 1);
      expect(shown.single.title, 'Hôm nay: 0 việc cần làm · 0 quá hạn');
      engine = ReminderEngine(db, scheduler, clock: () => now);
      await configure({'digestMinute': 480});
      scheduler.permission = false;
      await engine.reconcile([]);
      scheduler.permission = true;
      now = DateTime.utc(2026, 1, 5, 8);
      await engine.reconcile([]);
      expect(await engine.claimDue([]), isEmpty);
      expect(
        (await engine.events()).where((x) => x.state == 'unknown').length,
        1,
      );
    },
  );
  test(
    'late permission grant skips today and does not replay historical digest',
    () async {
      scheduler.permission = false;
      await configure({'digestEnabled': true});
      now = DateTime.utc(2026, 1, 5, 8);
      scheduler.permission = true;
      await engine.reconcile([]);
      expect(await engine.claimDue([]), isEmpty);
      expect(
        (await engine.events()).where((e) => e.state == 'scheduled').length,
        2,
      );
    },
  );
  test(
    'turning digest off cancels its slots and keeps task reminders',
    () async {
      await repo.save(
        TaskDraft(title: 'Việc', dueAt: DateTime.utc(2026, 1, 5, 10)),
      );
      await configure({'digestEnabled': true});
      expect(
        (await engine.events()).where((x) => x.state == 'scheduled').length,
        4,
      );
      await configure({'digestEnabled': false});
      final active = (await engine.events()).where(
        (x) => x.state == 'scheduled',
      );
      expect(active.length, 1);
      expect(active.single.ruleId, 'default');
    },
  );
  test('summary is read from fresh SQLite at display time', () async {
    final id = await repo.save(
      TaskDraft(
        title: 'Đã hoàn thành sau khi lập lịch',
        dueAt: DateTime.utc(2026, 1, 5, 6),
      ),
    );
    await configure({'digestEnabled': true});
    final stale = await repo.list();
    await repo.save(
      TaskDraft(
        title: 'Đã xong',
        dueAt: stale.single.dueAt,
        status: TaskStatus.completed,
      ),
      id: id,
      expectedRevision: stale.single.revision,
    );
    now = DateTime.utc(2026, 1, 5, 7);
    final due = await engine.claimDue(stale);
    expect(
      due.where((x) => x.ruleId == 'digest').single.title,
      'Hôm nay: 0 việc cần làm · 0 quá hạn',
    );
  });
  test('quiet hours defer within the day or suppress, never bunch a next-day digest', () async {
    await configure({
      'digestEnabled': true,
      'quietStart': 360,
      'quietEnd': 480,
    });
    final events = await engine.events();
    expect(
      events.every(
        (e) =>
            DateTime.fromMillisecondsSinceEpoch(
              e.scheduledMs,
              isUtc: true,
            ).hour ==
            8,
      ),
      isTrue,
    );
    await configure({
      'digestMinute': 1380,
      'quietStart': 1320,
      'quietEnd': 420,
    });
    expect(
      (await engine.events()).where((e) => e.state == 'scheduled'),
      isEmpty,
    );
  });
  test('a changed digest time rejects an obsolete scheduled slot before reconciliation', () async {
    await configure({'digestEnabled': true});
    final prefs = await engine.preferences();
    await engine.configure(
      NotificationPreferences.fromJson({
        ...prefs.toJson(),
        'digestMinute': 480,
      }),
    );
    now = DateTime.utc(2026, 1, 5, 7);
    expect(await engine.claimDue([]), isEmpty);
    await engine.reconcile([]);
    now = DateTime.utc(2026, 1, 5, 8);
    expect((await engine.claimDue([])).length, 1);
  });
  test('owner change invalidates the old digest before display', () async {
    await configure({'digestEnabled': true});
    await engine.records.put('account', 'session', {'ownerId': 'other'});
    now = DateTime.utc(2026, 1, 5, 7);
    expect(await engine.claimDue([]), isEmpty);
    expect((await engine.events()).where((e) => e.state == 'unknown'), isEmpty);
  });
}
