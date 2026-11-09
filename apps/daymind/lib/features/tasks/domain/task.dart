enum TaskPriority { low, medium, high }

enum TaskStatus { todo, inProgress, completed, cancelled }

class Task {
  const Task({
    required this.id,
    required this.title,
    this.description = '',
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    this.categoryId,
    this.dueAt,
    this.scheduledStartAt,
    this.scheduledEndAt,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.deletedAt,
    this.revision = 1,
    this.seriesId,
    this.occurrenceId,
    this.recurrenceRuleId,
    this.recurrenceRevision,
    this.seriesRevision,
    this.detached = false,
  });
  final String id, title, description;
  final TaskPriority priority;
  final TaskStatus status;
  final String? categoryId;
  final DateTime? dueAt,
      scheduledStartAt,
      scheduledEndAt,
      completedAt,
      deletedAt;
  final DateTime createdAt, updatedAt;
  final int revision;
  final String? seriesId, occurrenceId, recurrenceRuleId;
  final int? recurrenceRevision, seriesRevision;
  final bool detached;
  String get reminderTaskId => seriesId ?? id;
  int get reminderRevision => seriesRevision ?? revision;
  bool get terminal =>
      status == TaskStatus.completed || status == TaskStatus.cancelled;
  bool overdue(DateTime now) =>
      !terminal && deletedAt == null && dueAt != null && dueAt!.isBefore(now);
}

class TaskDraft {
  const TaskDraft({
    required this.title,
    this.description = '',
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    this.categoryId,
    this.dueAt,
    this.scheduledStartAt,
    this.scheduledEndAt,
  });
  factory TaskDraft.fromTask(Task task) => TaskDraft(
    title: task.title,
    description: task.description,
    priority: task.priority,
    status: task.status,
    categoryId: task.categoryId,
    dueAt: task.dueAt,
    scheduledStartAt: task.scheduledStartAt,
    scheduledEndAt: task.scheduledEndAt,
  );
  final String title, description;
  final TaskPriority priority;
  final TaskStatus status;
  final String? categoryId;
  final DateTime? dueAt, scheduledStartAt, scheduledEndAt;
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'priority': priority.name,
    'status': status.name,
    'categoryId': categoryId,
    'dueAt': dueAt?.toUtc().toIso8601String(),
    'scheduledStartAt': scheduledStartAt?.toUtc().toIso8601String(),
    'scheduledEndAt': scheduledEndAt?.toUtc().toIso8601String(),
  };
  factory TaskDraft.fromJson(Map<String, dynamic> value) => TaskDraft(
    title: value['title'] as String,
    description: value['description'] as String? ?? '',
    priority: TaskPriority.values.byName(
      value['priority'] as String? ?? 'medium',
    ),
    status: TaskStatus.values.byName(value['status'] as String? ?? 'todo'),
    categoryId: value['categoryId'] as String?,
    dueAt: readInstant(value['dueAt']),
    scheduledStartAt: readInstant(value['scheduledStartAt']),
    scheduledEndAt: readInstant(value['scheduledEndAt']),
  );
  void validate() {
    if (title.trim().isEmpty) {
      throw const ValidationException('Hãy đặt tên cho công việc.');
    }
    if (title.trim().length > 240) {
      throw const ValidationException('Tên công việc tối đa 240 ký tự.');
    }
    if (description.length > 10000) {
      throw const ValidationException('Mô tả tối đa 10.000 ký tự.');
    }
    if (scheduledStartAt != null &&
        scheduledEndAt != null &&
        scheduledEndAt!.isBefore(scheduledStartAt!)) {
      throw const ValidationException(
        'Giờ kết thúc phải sau hoặc bằng giờ bắt đầu.',
      );
    }
  }
}

DateTime? readInstant(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();

class Category {
  const Category(this.id, this.name, this.color);
  final String id, name;
  final int color;
}

class ValidationException implements Exception {
  const ValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class EditConflict implements Exception {
  const EditConflict();
  @override
  String toString() =>
      'Công việc vừa thay đổi. Bản nháp vẫn được giữ; hãy mở lại chi tiết trước khi lưu hoặc xóa.';
}

enum TaskView { today, all, inbox, upcoming, completed, trash }

bool sameDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

DateTime? nextDate(Task task, DateTime now) {
  final dates =
      [task.scheduledStartAt, task.dueAt]
          .whereType<DateTime>()
          .where((date) => date.isAfter(now) && !sameDay(date, now))
          .toList()
        ..sort();
  return dates.firstOrNull;
}

List<Task> filterTasks(
  List<Task> tasks, {
  required TaskView view,
  required DateTime now,
  String search = '',
  String? category,
  TaskPriority? priority,
  bool overdueOnly = false,
}) {
  final needle = search.trim().toLowerCase();
  final result = tasks.where((task) {
    if (view == TaskView.trash) {
      if (task.deletedAt == null) return false;
    } else if (task.deletedAt != null) {
      return false;
    }
    if (category != null && task.categoryId != category) return false;
    if (priority != null && task.priority != priority) return false;
    if (overdueOnly && !task.overdue(now)) return false;
    if (!'${task.title} ${task.description}'.toLowerCase().contains(needle)) {
      return false;
    }
    return switch (view) {
      TaskView.all || TaskView.trash => true,
      TaskView.inbox => !task.terminal && task.categoryId == null,
      TaskView.completed => task.status == TaskStatus.completed,
      TaskView.today =>
        !task.terminal &&
            (task.overdue(now) ||
                (task.dueAt != null && sameDay(task.dueAt!, now)) ||
                (task.scheduledStartAt != null &&
                    sameDay(task.scheduledStartAt!, now))),
      TaskView.upcoming => !task.terminal && nextDate(task, now) != null,
    };
  }).toList();
  result.sort((a, b) {
    final late = (b.overdue(now) ? 1 : 0).compareTo(a.overdue(now) ? 1 : 0);
    if (late != 0) return late;
    final ad = view == TaskView.upcoming
        ? nextDate(a, now)
        : a.dueAt ?? a.scheduledStartAt;
    final bd = view == TaskView.upcoming
        ? nextDate(b, now)
        : b.dueAt ?? b.scheduledStartAt;
    final date = ad == null
        ? (bd == null ? 0 : 1)
        : bd == null
        ? -1
        : ad.compareTo(bd);
    return date != 0 ? date : b.priority.index.compareTo(a.priority.index);
  });
  return result;
}

abstract interface class TaskRepository {
  Future<List<Task>> list();
  Future<List<Category>> categories();
  Future<String> save(TaskDraft draft, {String? id, int? expectedRevision});
  Future<void> delete(String id, int expectedRevision);
  Future<void> restore(String id, int expectedRevision);
  Future<void> addCategory(String name, int color);
}
