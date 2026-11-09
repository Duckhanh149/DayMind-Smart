import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/legacy.dart';

import '../features/tasks/domain/task.dart';
import '../features/tasks/data/database.dart' show SqliteTaskRepository;
import '../features/companion/domain/companion.dart';
import '../features/companion/data/asset_importer.dart';
import '../features/reminders/application/reminder_coordinator.dart';
import '../features/reminders/domain/reminder.dart';
import '../platform/window_lifecycle.dart';
import '../features/recurrence/application/recurrence_service.dart';
import '../features/recurrence/domain/recurrence.dart';
import '../features/assistant/domain/daily_assistant.dart';

final workspaceProvider = ChangeNotifierProvider<WorkspaceController>(
  (ref) => throw UnimplementedError(),
);

class WorkspaceController extends ChangeNotifier {
  WorkspaceController(
    this.repository,
    this.importer, {
    CompanionBehavior? behavior,
    DateTime Function()? clock,
  }) : behavior = behavior ?? CompanionBehavior(),
       now = clock ?? DateTime.now;
  final SqliteTaskRepository repository;
  final StaticAssetImporter importer;
  final CompanionBehavior behavior;
  final DateTime Function() now;
  late final recurrence = RecurrenceService(repository, clock: now);
  List<Task> tasks = [];
  List<Task> get visibleTasks => recurrence.project(tasks);
  Future<List<Task>> reminderTasks() async {
    tasks = await repository.list();
    await recurrence.materialize(tasks);
    return visibleTasks;
  }

  Future<void> calendarRange(String from, String through) => _write(() async {
    await recurrence.materialize(
      await repository.list(),
      from: from,
      through: through,
    );
  });
  List<Category> categories = [];
  AppPreferences preferences = const AppPreferences();
  DashboardPreferences dashboard = const DashboardPreferences();
  String dialogue = 'Không cần làm tất cả. Bắt đầu bằng một việc nhỏ thôi.';
  Future<void> _tail = Future.value();
  bool busy = false;
  int notificationOpenRequest = 0;
  void openNotifications() {
    notificationOpenRequest++;
    notifyListeners();
  }

  ReminderCoordinator? reminders;
  WindowLifecycle? window;
  void attachWindow(WindowLifecycle value) {
    window = value;
    value.addListener(notifyListeners);
  }

  void attachReminders(ReminderCoordinator coordinator) {
    reminders = coordinator;
    coordinator.addListener(notifyListeners);
  }

  Future<void> refreshFromNative() => _write(() async {});

  Future<void> load() async {
    tasks = await repository.list();
    await recurrence.materialize(tasks);
    categories = await repository.categories();
    preferences = AppPreferences.fromJson(await repository.readPreferences());
    dashboard = DashboardPreferences.fromJson(
      await recurrence.records.get('assistant', 'dashboard'),
    );
    dialogue =
        behavior.respond(CompanionEvent.appOpen, preferences.personality) ??
        dialogue;
    notifyListeners();
  }

  Future<T> _write<T>(Future<T> Function() action) {
    final operation = _tail.then((_) async {
      busy = true;
      notifyListeners();
      try {
        final result = await action();
        tasks = await repository.list();
        await recurrence.materialize(tasks);
        categories = await repository.categories();
        await reminders?.refresh();
        notifyListeners();
        return result;
      } finally {
        busy = false;
        notifyListeners();
      }
    });
    _tail = operation.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return operation;
  }

  Future<String> save(
    TaskDraft draft, {
    Task? existing,
    TaskReminderConfig? notifications,
    RepeatChange? repetition,
    EditScope scope = EditScope.one,
  }) => _write(
    () => repository.db.transaction(() async {
      if (existing?.occurrenceId != null) {
        if (scope != EditScope.one &&
            notifications?.rules.any((r) => r.kind == ReminderKind.absolute) ==
                true) {
          throw const ValidationException(
            'Ngày giờ nhắc riêng chỉ áp dụng cho một lần. Chuỗi dùng mốc tương đối.',
          );
        }
        await recurrence.edit(existing!, draft, scope, change: repetition);
        await recurrence.materialize(await repository.list());
        if (notifications != null && reminders != null) {
          final configId = scope == EditScope.one
              ? existing.id
              : scope == EditScope.all
              ? existing.seriesId!
              : recurrence.rules
                        .where(
                          (r) =>
                              r.taskId == existing.seriesId &&
                              r.activeFrom ==
                                  recurrence.occurrence(existing.id)?.date &&
                              r.enabled,
                        )
                        .lastOrNull
                        ?.id ??
                    existing.id;
          await reminders!.engine.configureTask(
            configId,
            notifications.mode,
            notifications.forTask(configId),
          );
        }
        return existing.id;
      }
      if (repetition?.enabled == true &&
          notifications?.rules.any((r) => r.kind == ReminderKind.absolute) ==
              true) {
        throw const ValidationException(
          'Chuỗi lặp dùng mốc nhắc tương đối. Ngày giờ riêng chỉ áp dụng khi sửa một lần.',
        );
      }
      final id = await repository.save(
        draft,
        id: existing?.id,
        expectedRevision: existing?.revision,
      );
      if (repetition != null) await recurrence.configure(id, repetition, draft);
      if (notifications != null && reminders != null) {
        await reminders!.engine.configureTask(
          id,
          notifications.mode,
          notifications.forTask(id),
        );
      }
      return id;
    }),
  );
  Future<void> toggle(Task task) => _write(() async {
    if (task.occurrenceId != null) {
      await recurrence.toggle(task);
    } else {
      await repository.save(
        TaskDraft(
          title: task.title,
          description: task.description,
          categoryId: task.categoryId,
          priority: task.priority,
          status: task.status == TaskStatus.completed
              ? TaskStatus.todo
              : TaskStatus.completed,
          dueAt: task.dueAt,
          scheduledStartAt: task.scheduledStartAt,
          scheduledEndAt: task.scheduledEndAt,
        ),
        id: task.id,
        expectedRevision: task.revision,
      );
    }
    if (task.status != TaskStatus.completed) {
      dialogue =
          behavior.respond(
            CompanionEvent.taskCompleted,
            preferences.personality,
          ) ??
          dialogue;
    }
  });
  Future<void> delete(Task task, {EditScope scope = EditScope.one}) => _write(
    () => repository.db.transaction(() async {
      if (task.occurrenceId == null) {
        await repository.delete(task.id, task.revision);
      } else {
        await recurrence.remove(task, scope: scope);
        await recurrence.materialize(await repository.list());
      }
    }),
  );
  Future<void> restore(Task task) => _write(
    () => task.occurrenceId == null
        ? repository.restore(task.id, task.revision)
        : recurrence.restore(task),
  );
  Future<void> configureDashboard(Set<String> cards) => _write(() async {
    if (cards.any((id) => !dashboardCards.containsKey(id))) {
      throw const ValidationException('Thẻ trang hôm nay không hợp lệ.');
    }
    dashboard = DashboardPreferences({...cards});
    await recurrence.records.put('assistant', 'dashboard', dashboard.toJson());
  });
  Future<void> addCategory(String name, int color) =>
      _write(() => repository.addCategory(name, color));
  Future<void> configure(AppPreferences Function(AppPreferences) update) =>
      _write(() async {
        final next = update(preferences);
        await repository.writePreferences(next.toJson());
        preferences = next;
        await window?.configure(next.windowsTrayEnabled);
      });
  @override
  void dispose() {
    window?.removeListener(notifyListeners);
    window?.dispose();
    reminders?.removeListener(notifyListeners);
    reminders?.dispose();
    super.dispose();
  }
}
