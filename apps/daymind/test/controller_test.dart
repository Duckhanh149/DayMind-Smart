import 'dart:io';
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/reminders/domain/reminder.dart';
import 'package:daymind_smart/features/reminders/application/reminder_engine.dart';
import 'package:daymind_smart/features/reminders/application/reminder_coordinator.dart';

import 'reminder_engine_test.dart' show FakeScheduler;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DaymindDatabase db;
  late WorkspaceController controller;
  late Directory temp;
  setUp(() async {
    db = DaymindDatabase(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('daymind-controller-');
    controller = WorkspaceController(
      SqliteTaskRepository(db),
      StaticAssetImporter(temp),
    );
    await controller.load();
  });
  tearDown(() async {
    controller.dispose();
    await db.close();
    await temp.delete(recursive: true);
  });
  test('queued setting updates preserve changes to different fields', () async {
    await Future.wait([
      controller.configure((prefs) => prefs.copyWith(theme: 'dark')),
      controller.configure((prefs) => prefs.copyWith(companionEnabled: false)),
    ]);
    expect(controller.preferences.theme, 'dark');
    expect(controller.preferences.companionEnabled, false);
  });
  test(
    'failed write keeps existing data, unlocks UI and allows the next save',
    () async {
      await controller.save(const TaskDraft(title: 'Bản hợp lệ'));
      await expectLater(
        controller.save(const TaskDraft(title: ' ')),
        throwsA(isA<ValidationException>()),
      );
      expect(controller.busy, false);
      expect(controller.tasks.single.title, 'Bản hợp lệ');
      await controller.save(const TaskDraft(title: 'Lưu tiếp được'));
      expect(controller.tasks.length, 2);
    },
  );
  test(
    'dashboard selection persists across load, including an empty selection',
    () async {
      await controller.configureDashboard({});
      await controller.load();
      expect(controller.dashboard.cards, isEmpty);
      await expectLater(
        controller.configureDashboard({'unknown'}),
        throwsA(isA<ValidationException>()),
      );
      expect(controller.dashboard.cards, isEmpty);
      await controller.configureDashboard({'today', 'suggestions'});
      await controller.load();
      expect(controller.dashboard.cards, {'today', 'suggestions'});
    },
  );
  test('a settings change during reminder refresh is reconciled after the active cycle', () async {
    final entered = Completer<void>(),
        release = Completer<void>(),
        applied = Completer<void>();
    var reads = 0;
    final coordinator = ReminderCoordinator(
      ReminderEngine(db, FakeScheduler()),
      () async {
        reads++;
        if (reads == 1) {
          entered.complete();
          await release.future;
        }
        return controller.repository.list();
      },
    );
    controller.attachReminders(coordinator);
    coordinator.addListener(() {
      if (reads >= 2 &&
          coordinator.preferences.digestEnabled &&
          coordinator.events.any((e) => e.ruleId == 'digest') &&
          !applied.isCompleted) {
        applied.complete();
      }
    });
    final first = coordinator.refresh();
    await entered.future;
    await coordinator.configure({'digestEnabled': true});
    release.complete();
    await first;
    await applied.future.timeout(const Duration(seconds: 5));
    expect(reads, greaterThanOrEqualTo(2));
    expect(coordinator.preferences.digestEnabled, isTrue);
  });
  test(
    'Windows-style live grouping preserves an earlier high-priority reminder',
    () async {
      var now = DateTime.utc(2026, 1, 5, 8, 59);
      final repo = SqliteTaskRepository(db, clock: () => now),
          scheduler = FakeScheduler();
      final high = await repo.save(
        const TaskDraft(title: 'Ưu tiên cần giữ', priority: TaskPriority.high),
      );
      final low = await repo.save(const TaskDraft(title: 'Việc đến sau'));
      final engine = ReminderEngine(db, scheduler, clock: () => now);
      await engine.configure(
        const NotificationPreferences(
          quietEnabled: false,
          preset: ReminderPreset.minimal,
        ),
      );
      await engine.configureTask(high, 'custom', [
        ReminderRule(
          id: 'high-rule',
          taskId: high,
          kind: ReminderKind.absolute,
          absoluteAt: DateTime.utc(2026, 1, 5, 9),
        ),
      ]);
      await engine.configureTask(low, 'custom', [
        ReminderRule(
          id: 'low-rule',
          taskId: low,
          kind: ReminderKind.absolute,
          absoluteAt: DateTime.utc(2026, 1, 5, 9, 1),
        ),
      ]);
      final coordinator = ReminderCoordinator(engine, repo.list)
        ..setWindowVisible(false);
      controller.attachReminders(coordinator);
      await coordinator.refresh();
      now = DateTime.utc(2026, 1, 5, 9);
      await coordinator.refresh(replan: false);
      now = DateTime.utc(2026, 1, 5, 9, 1);
      await coordinator.refresh(replan: false);
      expect(scheduler.shown.length, 2);
      expect(scheduler.shown.last.id, scheduler.shown.first.id);
      expect(scheduler.shown.last.body, contains('Ưu tiên cần giữ'));
      expect(scheduler.shown.last.body, contains('Việc đến sau'));
      expect(scheduler.shown.last.title, contains('Ưu tiên cao'));
    },
  );
  test('tray polling extends daily digest dates without reopening the window or replaying past days', () async {
    var now = DateTime.utc(2026, 1, 5);
    final scheduler = FakeScheduler();
    final engine = ReminderEngine(db, scheduler, clock: () => now);
    await engine.configure(const NotificationPreferences(digestEnabled: true));
    final coordinator = ReminderCoordinator(engine, controller.repository.list)
      ..setWindowVisible(false);
    controller.attachReminders(coordinator);
    await coordinator.refresh();
    now = DateTime.utc(2026, 1, 8);
    await coordinator.refresh(replan: false);
    final scheduled = (await engine.events())
        .where((e) => e.state == 'scheduled')
        .toList();
    expect(scheduled.length, 3);
    expect(
      scheduled.every((e) => e.scheduledMs > now.millisecondsSinceEpoch),
      isTrue,
    );
    expect(scheduler.shown, isEmpty);
    expect((await engine.events()).where((e) => e.state == 'unknown'), isEmpty);
  });
  test('tasks work normally with companion turned off', () async {
    await controller.configure(
      (prefs) => prefs.copyWith(companionEnabled: false),
    );
    await controller.save(const TaskDraft(title: 'Độc lập với Companion'));
    await controller.toggle(controller.tasks.single);
    expect(controller.tasks.single.status, TaskStatus.completed);
    expect(controller.preferences.companionEnabled, false);
  });
  test('task and custom reminder save atomically; permission denial never blocks CRUD', () async {
    final scheduler = FakeScheduler()..permission = false;
    controller.attachReminders(
      ReminderCoordinator(
        ReminderEngine(db, scheduler),
        controller.repository.list,
      ),
    );
    await expectLater(
      controller.save(
        const TaskDraft(title: 'Không được lưu một nửa'),
        notifications: const TaskReminderConfig('custom', [
          ReminderRule(id: 'bad', taskId: 'new', offsetMinutes: -1),
        ]),
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(await controller.repository.list(), isEmpty);
    await controller.save(
      const TaskDraft(title: 'Lưu dù chưa có quyền'),
      notifications: const TaskReminderConfig('off', []),
    );
    expect(controller.tasks.single.title, 'Lưu dù chưa có quyền');
    expect(controller.busy, isFalse);
    expect(scheduler.active, isEmpty);
    await controller.toggle(controller.tasks.single);
    expect(controller.tasks.single.status, TaskStatus.completed);
  });
}
