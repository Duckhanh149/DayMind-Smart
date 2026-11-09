import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/legacy.dart';

import '../features/tasks/domain/task.dart';
import '../features/tasks/data/database.dart' show SqliteTaskRepository;
import '../features/companion/domain/companion.dart';
import '../features/companion/data/asset_importer.dart';
import '../features/reminders/application/reminder_coordinator.dart';
import '../features/reminders/domain/reminder.dart';

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
  List<Task> tasks = [];
  List<Category> categories = [];
  AppPreferences preferences = const AppPreferences();
  String dialogue = 'Không cần làm tất cả. Bắt đầu bằng một việc nhỏ thôi.';
  Future<void> _tail = Future.value();
  bool busy = false;
  int notificationOpenRequest = 0;
  void openNotifications() {
    notificationOpenRequest++;
    notifyListeners();
  }

  ReminderCoordinator? reminders;
  void attachReminders(ReminderCoordinator coordinator) {
    reminders = coordinator;
    coordinator.addListener(notifyListeners);
  }

  Future<void> refreshFromNative() async {
    tasks = await repository.list();
    notifyListeners();
  }

  Future<void> load() async {
    tasks = await repository.list();
    categories = await repository.categories();
    preferences = AppPreferences.fromJson(await repository.readPreferences());
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
  }) => _write(
    () => repository.db.transaction(() async {
      final id = await repository.save(
        draft,
        id: existing?.id,
        expectedRevision: existing?.revision,
      );
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
    if (task.status != TaskStatus.completed) {
      dialogue =
          behavior.respond(
            CompanionEvent.taskCompleted,
            preferences.personality,
          ) ??
          dialogue;
    }
  });
  Future<void> delete(Task task) =>
      _write(() => repository.delete(task.id, task.revision));
  Future<void> restore(Task task) =>
      _write(() => repository.restore(task.id, task.revision));
  Future<void> addCategory(String name, int color) =>
      _write(() => repository.addCategory(name, color));
  Future<void> configure(AppPreferences Function(AppPreferences) update) =>
      _write(() async {
        final next = update(preferences);
        await repository.writePreferences(next.toJson());
        preferences = next;
      });
  @override
  void dispose() {
    reminders?.removeListener(notifyListeners);
    reminders?.dispose();
    super.dispose();
  }
}
