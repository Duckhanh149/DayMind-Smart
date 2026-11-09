import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/recurrence/domain/recurrence.dart';
import 'package:daymind_smart/features/recurrence/application/recurrence_service.dart';

void main() {
  zones.initializeTimeZones();
  const generator = RecurrenceGenerator();
  test('monthly 31 explicitly skips or clamps, including leap February', () {
    RepeatSpec spec(MonthDayPolicy policy) => RepeatSpec(
      frequency: RepeatFrequency.monthly,
      firstDate: '2024-01-31',
      zone: 'UTC',
      monthPolicy: policy,
    );
    expect(
      generator.dates(spec(MonthDayPolicy.skip), '2024-01-01', '2024-05-31'),
      ['2024-01-31', '2024-03-31', '2024-05-31'],
    );
    expect(
      generator.dates(spec(MonthDayPolicy.lastDay), '2024-01-01', '2024-05-31'),
      ['2024-01-31', '2024-02-29', '2024-03-31', '2024-04-30', '2024-05-31'],
    );
    expect(
      () => generator.dates(
        const RepeatSpec(
          frequency: RepeatFrequency.monthly,
          firstDate: '2026-01-31',
          zone: 'UTC',
        ),
        '2026-01-01',
        '2026-02-28',
      ),
      throwsA(isA<ValidationException>()),
    );
  });
  test(
    'weekly cadence uses Monday weeks; count is global, not per query range',
    () {
      const spec = RepeatSpec(
        frequency: RepeatFrequency.weekly,
        firstDate: '2026-01-07',
        zone: 'UTC',
        interval: 2,
        weekdays: [1, 3, 5],
        count: 5,
      );
      expect(generator.dates(spec, '2026-01-01', '2026-03-01'), [
        '2026-01-07',
        '2026-01-09',
        '2026-01-19',
        '2026-01-21',
        '2026-01-23',
      ]);
      expect(generator.dates(spec, '2026-01-20', '2026-03-01'), [
        '2026-01-21',
        '2026-01-23',
      ]);
    },
  );
  test('daily interval and inclusive end date are calendar dates', () {
    const spec = RepeatSpec(
      frequency: RepeatFrequency.daily,
      firstDate: '2026-01-01',
      zone: 'Asia/Ho_Chi_Minh',
      interval: 2,
      until: '2026-01-07',
    );
    expect(generator.dates(spec, '2026-01-01', '2026-01-20'), [
      '2026-01-01',
      '2026-01-03',
      '2026-01-05',
      '2026-01-07',
    ]);
  });
  test('DST gap moves to first valid minute; fold selects first instant', () {
    expect(
      resolveWall('America/New_York', '2026-03-08', 150),
      DateTime.utc(2026, 3, 8, 7),
    );
    expect(wallCandidates('America/New_York', '2026-11-01', 90), [
      DateTime.utc(2026, 11, 1, 5, 30),
      DateTime.utc(2026, 11, 1, 6, 30),
    ]);
    expect(
      resolveWall('America/New_York', '2026-11-01', 90),
      DateTime.utc(2026, 11, 1, 5, 30),
    );
  });
  test('DST preserves elapsed duration and moves independent deadline by wall date', () {
    final rule = RecurrenceRule(
      id: 'r',
      taskId: 't',
      spec: const RepeatSpec(
        frequency: RepeatFrequency.daily,
        firstDate: '2026-03-07',
        zone: 'America/New_York',
        minute: 150,
      ),
      templateDate: '2026-03-07',
      template: TaskDraft(
        title: 'DST',
        scheduledStartAt: DateTime.utc(2026, 3, 7, 7, 30),
        scheduledEndAt: DateTime.utc(2026, 3, 7, 8, 30),
        dueAt: DateTime.utc(2026, 3, 7, 10),
      ),
    );
    final o = generator.occurrence(rule, '2026-03-08', DateTime.utc(2026));
    expect(o.draft.scheduledStartAt, DateTime.utc(2026, 3, 8, 7));
    expect(o.draft.scheduledEndAt, DateTime.utc(2026, 3, 8, 8));
    expect(o.draft.dueAt, DateTime.utc(2026, 3, 8, 9));
  });
  test('missing civil date is recorded skipped; stable IDs do not depend on current device zone', () {
    final rule = RecurrenceRule(
      id: 'rule',
      taskId: 'task',
      spec: const RepeatSpec(
        frequency: RepeatFrequency.daily,
        firstDate: '2011-12-29',
        zone: 'Pacific/Apia',
      ),
      template: const TaskDraft(title: 'Routine'),
      templateDate: '2011-12-29',
    );
    final missing = generator.occurrence(
      rule,
      '2011-12-30',
      DateTime.utc(2011, 12, 29),
    );
    expect(missing.skipped, isTrue);
    expect(
      generator.occurrence(rule, '2011-12-30', DateTime.utc(2012)).id,
      missing.id,
    );
  });
  test('invalid intervals, dates, weekdays and ranges are rejected', () {
    expect(() => civilDate('2026-02-31'), throwsA(isA<ValidationException>()));
    expect(
      () => const RepeatSpec(
        frequency: RepeatFrequency.weekly,
        firstDate: '2026-01-01',
        zone: 'UTC',
      ).validate(),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => const RepeatSpec(
        frequency: RepeatFrequency.daily,
        firstDate: '2026-01-01',
        zone: 'UTC',
        interval: 0,
      ).validate(),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => const RepeatSpec(
        frequency: RepeatFrequency.daily,
        firstDate: '2026-01-01',
        zone: 'UTC',
        until: '2025-12-31',
      ).validate(),
      throwsA(isA<ValidationException>()),
    );
  });
  group('persisted series and exceptions', () {
    late DaymindDatabase db;
    late SqliteTaskRepository repo;
    late RecurrenceService service;
    late String id;
    final now = DateTime.utc(2026, 1, 5);
    setUp(() async {
      db = DaymindDatabase(NativeDatabase.memory());
      repo = SqliteTaskRepository(db, clock: () => now);
      service = RecurrenceService(repo, clock: () => now);
      id = await repo.save(
        TaskDraft(
          title: 'Việc gốc',
          scheduledStartAt: DateTime.utc(2026, 1, 5, 2),
          scheduledEndAt: DateTime.utc(2026, 1, 5, 3),
          dueAt: DateTime.utc(2026, 1, 5, 10),
        ),
      );
      await service.configure(
        id,
        const RepeatChange(
          enabled: true,
          spec: RepeatSpec(
            frequency: RepeatFrequency.daily,
            firstDate: '2026-01-05',
            zone: 'Asia/Ho_Chi_Minh',
          ),
        ),
        TaskDraft.fromTask((await repo.list()).single),
      );
    });
    tearDown(() => db.close());
    Future<void> materialize() async => service.materialize(
      await repo.list(),
      from: '2026-01-05',
      through: '2026-01-10',
    );
    Future<Task> at(String date) async {
      await service.reload();
      final root = (await repo.list()).single;
      final o = service.occurrences.singleWhere(
        (o) => o.date == date && !o.deleted,
      );
      return o.project(root, ruleRevision: service.rule(o.ruleId)?.revision);
    }

    test('repeat materialization is idempotent and completion affects one occurrence', () async {
      await materialize();
      await materialize();
      expect(service.occurrences.length, 6);
      await service.toggle(await at('2026-01-05'));
      await materialize();
      expect((await repo.list()).single.status, TaskStatus.todo);
      expect(
        service.occurrences
            .where((o) => o.draft.status == TaskStatus.completed)
            .length,
        1,
      );
      expect((await at('2026-01-06')).status, TaskStatus.todo);
    });
    test(
      'one edit remains an exception across an all-series template update',
      () async {
        await materialize();
        final first = await at('2026-01-05');
        await service.edit(
          first,
          TaskDraft.fromJson({
            ...TaskDraft.fromTask(first).toJson(),
            'title': 'Ngoại lệ',
          }),
          EditScope.one,
        );
        await materialize();
        final next = await at('2026-01-06');
        await service.edit(
          next,
          TaskDraft.fromJson({
            ...TaskDraft.fromTask(next).toJson(),
            'title': 'Mẫu mới',
            'priority': 'high',
          }),
          EditScope.all,
        );
        await materialize();
        expect((await at('2026-01-05')).title, 'Ngoại lệ');
        expect((await at('2026-01-05')).priority, TaskPriority.high);
        expect((await at('2026-01-07')).title, 'Mẫu mới');
      },
    );
    test(
      'future split preserves history and does not duplicate a completed date',
      () async {
        await materialize();
        await service.toggle(await at('2026-01-05'));
        await materialize();
        final selected = await at('2026-01-07');
        await service.edit(
          selected,
          TaskDraft.fromJson({
            ...TaskDraft.fromTask(selected).toJson(),
            'title': 'Từ lần này',
          }),
          EditScope.future,
        );
        await materialize();
        expect((await at('2026-01-05')).title, 'Việc gốc');
        expect((await at('2026-01-05')).status, TaskStatus.completed);
        expect((await at('2026-01-06')).title, 'Việc gốc');
        expect((await at('2026-01-07')).title, 'Từ lần này');
        expect(
          service.occurrences
              .where((o) => o.date == '2026-01-07' && !o.deleted)
              .length,
          1,
        );
      },
    );
    test(
      'stale instance and rule forms are rejected without losing text',
      () async {
        await materialize();
        final old = await at('2026-01-05');
        await service.toggle(old);
        await expectLater(
          service.edit(old, const TaskDraft(title: 'Stale'), EditScope.one),
          throwsA(isA<EditConflict>()),
        );
        final a = await at('2026-01-06'), b = await at('2026-01-07');
        await service.edit(
          a,
          TaskDraft.fromJson({
            ...TaskDraft.fromTask(a).toJson(),
            'title': 'Bản mới',
          }),
          EditScope.all,
        );
        await expectLater(
          service.edit(b, const TaskDraft(title: 'Ghi đè cũ'), EditScope.all),
          throwsA(isA<EditConflict>()),
        );
      },
    );
    test('cadence edit removes future generated dates but preserves completed history', () async {
      await materialize();
      await service.toggle(await at('2026-01-05'));
      await materialize();
      final chosen = await at('2026-01-06');
      await service.edit(
        chosen,
        TaskDraft.fromTask(chosen),
        EditScope.all,
        change: const RepeatChange(
          enabled: true,
          spec: RepeatSpec(
            frequency: RepeatFrequency.weekly,
            firstDate: '2026-01-05',
            zone: 'Asia/Ho_Chi_Minh',
            weekdays: [3],
          ),
        ),
      );
      await materialize();
      final visible = service.occurrences.where((o) => !o.deleted).toList();
      expect(visible.map((o) => o.date), contains('2026-01-05'));
      expect(visible.where((o) => !o.terminal).map((o) => o.date), [
        '2026-01-07',
      ]);
    });
    test('delete and restore root preserve occurrence history; stop future preserves past', () async {
      await materialize();
      await service.toggle(await at('2026-01-05'));
      await materialize();
      final root = (await repo.list()).single;
      await repo.delete(id, root.revision);
      await materialize();
      expect(
        service.project(await repo.list()).where((t) => t.occurrenceId != null),
        isEmpty,
      );
      await repo.restore(id, (await repo.list()).single.revision);
      await materialize();
      expect((await at('2026-01-05')).status, TaskStatus.completed);
      await service.remove(await at('2026-01-08'), scope: EditScope.future);
      await materialize();
      expect(
        service.occurrences.where((o) => !o.deleted).map((o) => o.date),
        isNot(contains('2026-01-09')),
      );
      expect((await at('2026-01-05')).status, TaskStatus.completed);
    });
  });
}
