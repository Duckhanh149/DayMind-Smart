import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/painting.dart' show PaintingBinding;
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
  }) : behavior = behavior ?? CompanionBehavior(clock: clock),
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
  CompanionProfile companion = CompanionProfile();
  CompanionLayout companionLayout = const CompanionLayout();
  CompanionExpression expression = CompanionExpression.neutral;
  Map<CompanionExpression, String> expressionAssets = {};
  String? companionError;
  int inAppSequence = 0;
  String? inAppAnnouncement;

  String? get companionAssetName =>
      expressionAssets[expression] ?? preferences.assetName;
  Future<void> _loadCompanion() async {
    companionError = null;
    try {
      final data = await recurrence.records.get('companion_profile', 'primary');
      companion = data == null
          ? CompanionProfile(personality: preferences.personality)
          : CompanionProfile.fromJson(data);
      companionLayout = CompanionLayout.fromJson(
        await recurrence.records.get('companion_local', 'layout'),
      );
      final art =
          await recurrence.records.get('companion_local', 'expressions') ?? {};
      expressionAssets = {
        for (final e in CompanionExpression.values)
          if (art[e.name] is String &&
              RegExp(r'^[a-f0-9]{64}\.(png|webp)$')
                  .hasMatch(art[e.name] as String))
            e: art[e.name] as String,
      };
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          (companionLayout.lowResource ? 4 : 16) * 1024 * 1024;
    } catch (_) {
      companion = CompanionProfile(personality: preferences.personality);
      companionLayout = const CompanionLayout();
      expressionAssets = {};
      companionError = 'Chưa đọc được hồ sơ Companion. Mầm dùng cấu hình mặc định; công việc vẫn được giữ.';
    }
  }

  void reactCompanion(CompanionEvent event, {String? task, String? summary}) {
    if (!preferences.companionEnabled) return;
    final settings = reminders?.preferences ?? const NotificationPreferences();
    final reply = behavior.react(
      event,
      companion,
      quiet: settings.quietAt(now()),
      task: task,
      summary: summary,
      day: localDay(now(), settings.timezoneId),
    );
    expression = reply.expression;
    if (reply.text != null) dialogue = reply.text!;
  }

  void foregroundReminder(CompanionCue cue) {
    inAppAnnouncement = cue.announcement;
    inAppSequence++;
    if (preferences.companionEnabled) {
      reactCompanion(cue.event, task: cue.task, summary: cue.summary);
    }
    notifyListeners();
  }

  Future<void> overdueVisible() async {
    if (!preferences.companionEnabled ||
        !visibleTasks.any(
          (t) =>
              t.deletedAt == null &&
              !t.terminal &&
              t.dueAt != null &&
              t.dueAt!.isBefore(now()),
        )) {
      return;
    }
    await _write(() async {
      final settings =
          reminders?.preferences ?? const NotificationPreferences();
      final day = localDay(now(), settings.timezoneId);
      if ((await recurrence.records.get(
            'companion_local',
            'overdue',
          ))?['day'] ==
          day) {
        return;
      }
      final reply = behavior.react(
        CompanionEvent.taskOverdueVisible,
        companion,
        quiet: settings.quietAt(now()),
        day: day,
      );
      if (reply.text == null) return;
      dialogue = reply.text!;
      expression = reply.expression;
      await recurrence.records.put('companion_local', 'overdue', {'day': day});
    }, localChange: false);
  }

  Future<void> saveCompanion(
    CompanionProfile value, {
    CompanionProfile? expected,
  }) => _write(() async {
    value.validate();
    await repository.db.transaction(() async {
      if (expected != null) {
        final stored = await recurrence.records.get(
          'companion_profile',
          'primary',
        );
        final fresh = stored == null
            ? CompanionProfile(
                personality: AppPreferences.fromJson(
                  await repository.readPreferences(),
                ).personality,
              )
            : CompanionProfile.fromJson(stored);
        if (!fresh.sameAs(expected)) {
          throw const CompanionValidation(
            'Hồ sơ đã thay đổi trên thiết bị khác. Bản đang nhập được giữ; hãy mở lại để so sánh trước khi lưu.',
          );
        }
      }
      await recurrence.records.put(
        'companion_profile',
        'primary',
        value.toJson(),
      );
      preferences = preferences.copyWith(personality: value.personality);
      await repository.writePreferences(preferences.toJson());
    });
    dialogue = value.messageFor(CompanionEvent.appOpen);
    expression = value.expressionFor(CompanionEvent.appOpen);
  });
  Future<void> configureCompanionLayout(CompanionLayout value) => _write(
    () async {
      value.validate();
      await recurrence.records.put('companion_local', 'layout', value.toJson());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    },
    localChange: false,
  );
  Future<void> updateCompanionLayout(
    CompanionLayout Function(CompanionLayout) update,
  ) => _write(() async {
    final value = update(companionLayout);
    value.validate();
    await recurrence.records.put('companion_local', 'layout', value.toJson());
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }, localChange: false);
  Future<void> removeCompanionAsset(String name) => _write(() async {
    await importer.remove(name);
    if (preferences.assetName == name) {
      preferences = preferences.copyWith(resetAsset: true);
      await repository.writePreferences(preferences.toJson());
    }
    await recurrence.records.put('companion_local', 'expressions', {
      for (final e in expressionAssets.entries)
        if (e.value != name) e.key.name: e.value,
    });
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }, localChange: false);
  Future<void> mapExpression(CompanionExpression selected, String? name) =>
      _write(() async {
        if (name != null && importer.resolve(name)?.existsSync() != true) {
          throw const CompanionValidation(
            'Hãy chọn một ảnh trong thư viện trên thiết bị này.',
          );
        }
        final next = {...expressionAssets};
        if (name == null) {
          next.remove(selected);
        } else {
          next[selected] = name;
        }
        await recurrence.records.put('companion_local', 'expressions', {
          for (final e in next.entries) e.key.name: e.value,
        });
        PaintingBinding.instance.imageCache.clear();
      }, localChange: false);
  DashboardPreferences dashboard = const DashboardPreferences();
  String dialogue = 'Không cần làm tất cả. Bắt đầu bằng một việc nhỏ thôi.';
  Future<void> _tail = Future.value();
  bool busy = false;
  bool _closed = false, _disposed = false;
  void Function()? onLocalChange;
  Future<void> drain() async {
    _closed = true;
    await _tail;
  }

  void resumeWrites() {
    if (!_disposed) _closed = false;
  }

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
  Future<void> refreshFromSync() => _write(() async {}, localChange: false);

  Future<void> load() async {
    tasks = await repository.list();
    await recurrence.materialize(tasks);
    categories = await repository.categories();
    preferences = AppPreferences.fromJson(await repository.readPreferences());
    await _loadCompanion();
    dashboard = DashboardPreferences.fromJson(
      await recurrence.records.get('assistant', 'dashboard'),
    );
    final reply = behavior.react(
      CompanionEvent.appOpen,
      companion,
      quiet: (reminders?.preferences ?? const NotificationPreferences())
          .quietAt(now()),
    );
    dialogue = reply.text ?? 'Mầm đang nghỉ ngơi.';
    expression = reply.expression;
    notifyListeners();
  }

  Future<T> _write<T>(Future<T> Function() action, {bool localChange = true}) {
    if (_closed) return Future.error(StateError('Không gian đang được đóng.'));
    final operation = _tail.then((_) async {
      busy = true;
      notifyListeners();
      try {
        final result = await action();
        if (localChange) onLocalChange?.call();
        tasks = await repository.list();
        await recurrence.materialize(tasks);
        categories = await repository.categories();
        await _loadCompanion();
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
            notifications?.mode == 'custom' &&
            notifications!.rules.any((r) => r.kind == ReminderKind.absolute)) {
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
          notifications == null &&
          existing != null &&
          reminders != null) {
        final saved = await reminders!.engine.records.get(
          'task_reminders',
          existing.id,
        );
        if (saved?['mode'] == 'custom' &&
            (await reminders!.engine.rules(existing.id))
                .any((r) => r.kind == ReminderKind.absolute)) {
          throw const ValidationException(
            'Chuỗi lặp dùng mốc nhắc tương đối. Hãy đổi hoặc tắt mốc ngày giờ riêng trước khi bật lặp.',
          );
        }
      }
      if (repetition?.enabled == true &&
          notifications?.mode == 'custom' &&
          notifications!.rules.any((r) => r.kind == ReminderKind.absolute)) {
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
      reactCompanion(CompanionEvent.taskCompleted, task: task.title);
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
        if (next.personality != preferences.personality) {
          await recurrence.records.put(
            'companion_profile',
            'primary',
            companion.copy(personality: next.personality).toJson(),
          );
        }
        await repository.writePreferences(next.toJson());
        preferences = next;
        await window?.configure(next.windowsTrayEnabled);
      });
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _closed = true;
    window?.removeListener(notifyListeners);
    reminders?.removeListener(notifyListeners);
    reminders?.dispose();
    super.dispose();
  }
}
