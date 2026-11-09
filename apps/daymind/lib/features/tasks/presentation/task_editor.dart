import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/controller.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/presentation/reminder_editor.dart';
import '../domain/task.dart';
import '../../recurrence/domain/recurrence.dart';
import '../../recurrence/application/recurrence_service.dart';
import '../../recurrence/presentation/recurrence_editor.dart';

import 'package:timezone/timezone.dart' as tz;

const priorityLabels = ['Thấp', 'Vừa', 'Cao'];
const statusLabels = ['Cần làm', 'Đang làm', 'Đã hoàn thành', 'Đã hủy'];
String dateLabel(DateTime value, {bool local = true}) {
  final date = local ? value.toLocal() : value;
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

Future<void> showTaskEditor(
  BuildContext context, {
  Task? task,
  String? categoryId,
}) => showDialog<void>(
  context: context,
  builder: (_) => TaskEditor(task: task, categoryId: categoryId),
);

class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor({super.key, this.task, this.categoryId});
  final Task? task;
  final String? categoryId;
  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  late final title = TextEditingController(text: widget.task?.title);
  late final description = TextEditingController(
    text: widget.task?.description,
  );
  late TaskPriority priority = widget.task?.priority ?? TaskPriority.medium;
  late TaskStatus status = widget.task?.status ?? TaskStatus.todo;
  late String? category = widget.task?.categoryId ?? widget.categoryId;
  late DateTime? due = widget.task?.dueAt,
      start = widget.task?.scheduledStartAt,
      end = widget.task?.scheduledEndAt;
  bool saving = false;
  String? error;
  TaskReminderConfig? reminderConfig;
  RepeatChange? repeatChange;
  late final initialRule = ref
      .read(workspaceProvider)
      .recurrence
      .rule(widget.task?.recurrenceRuleId);
  String get editorZone {
    final value =
        repeatChange?.spec?.zone ??
        initialRule?.spec.zone ??
        ref.read(workspaceProvider).reminders?.preferences.timezoneId ??
        'UTC';
    try {
      zoneLocation(value);
      return value;
    } catch (_) {
      return initialRule?.spec.zone ?? 'UTC';
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<DateTime?> pick(DateTime? initial) async {
    final local = tz.TZDateTime.from(
      initial ?? DateTime.now(),
      zoneLocation(editorZone),
    );
    final date = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return initial;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (time == null) return initial;
    return resolveWall(editorZone, dateKey(date), time.hour * 60 + time.minute);
  }

  Future<void> save() async {
    if (saving) return;
    final scope = widget.task?.occurrenceId == null
        ? EditScope.one
        : await chooseEditScope(context, scheduleChanged: repeatChange != null);
    if (scope == null || !mounted) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(workspaceProvider)
          .save(
            TaskDraft(
              title: title.text,
              description: description.text,
              priority: priority,
              status: status,
              categoryId: category,
              dueAt: due,
              scheduledStartAt: start,
              scheduledEndAt: end,
            ),
            existing: widget.task,
            notifications: reminderConfig,
            repetition: repeatChange,
            scope: scope,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Widget dateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: saving
                ? null
                : () async {
                    final result = await pick(value);
                    if (mounted) setState(() => changed(result));
                  },
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(
              '$label: ${value == null ? 'Chưa đặt' : dateLabel(tz.TZDateTime.from(value, zoneLocation(editorZone)), local: false)}',
            ),
          ),
        ),
        if (value != null)
          IconButton(
            onPressed: saving ? null : () => setState(() => changed(null)),
            icon: const Icon(Icons.close),
            tooltip: 'Bỏ $label',
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(workspaceProvider);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final warning = end != null && due != null && end!.isAfter(due!)
        ? 'Lịch kết thúc sau hạn hoàn thành. Bạn vẫn có thể lưu nếu đây là chủ ý của bạn.'
        : null;
    return Dialog(
      insetPadding: EdgeInsets.all(compact ? 12 : 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.task == null
                          ? 'Một công việc mới'
                          : 'Chi tiết công việc',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('task-title'),
                        controller: title,
                        maxLength: 240,
                        autofocus: false,
                        decoration: const InputDecoration(
                          labelText: 'Tên công việc *',
                          hintText: 'Bạn muốn hoàn thành điều gì?',
                        ),
                      ),
                      dateField('Hạn hoàn thành', due, (value) => due = value),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Không bắt buộc đặt hạn. Bạn có thể tùy chỉnh hoặc tắt nhắc cho từng việc.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ExpansionTile(
                        initiallyExpanded: widget.task != null,
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Chi tiết & lên lịch'),
                        children: [
                          TextField(
                            controller: description,
                            minLines: 2,
                            maxLines: 5,
                            maxLength: 10000,
                            decoration: const InputDecoration(
                              labelText: 'Mô tả / ghi chú',
                            ),
                          ),
                          DropdownButtonFormField<TaskPriority>(
                            isExpanded: true,
                            initialValue: priority,
                            decoration: const InputDecoration(
                              labelText: 'Ưu tiên',
                            ),
                            items: TaskPriority.values
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(priorityLabels[p.index]),
                                  ),
                                )
                                .toList(),
                            onChanged: saving
                                ? null
                                : (p) => setState(() => priority = p!),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: category ?? '',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Danh mục',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Hộp thư · Chưa phân loại'),
                              ),
                              ...controller.categories.map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              ),
                            ],
                            onChanged: saving
                                ? null
                                : (c) => setState(
                                    () => category = c == '' ? null : c,
                                  ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<TaskStatus>(
                            isExpanded: true,
                            initialValue: status,
                            decoration: const InputDecoration(
                              labelText: 'Trạng thái',
                            ),
                            items: TaskStatus.values
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(statusLabels[s.index]),
                                  ),
                                )
                                .toList(),
                            onChanged: saving
                                ? null
                                : (s) => setState(() => status = s!),
                          ),
                          const SizedBox(height: 16),
                          dateField('Bắt đầu', start, (value) => start = value),
                          dateField('Kết thúc', end, (value) => end = value),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Lịch thực hiện và hạn hoàn thành là các mốc riêng biệt.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          RecurrenceEditor(
                            initial: initialRule?.spec,
                            date: tz.TZDateTime.from(
                              start ?? due ?? controller.now(),
                              zoneLocation(editorZone),
                            ),
                            zone: editorZone,
                            onChanged: (value) =>
                                setState(() => repeatChange = value),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Giờ đang nhập theo $editorZone',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (controller.reminders != null)
                            ReminderEditor(
                              engine: controller.reminders!.engine,
                              task: Task(
                                id: widget.task?.id ?? 'new',
                                seriesId: widget.task?.seriesId,
                                recurrenceRuleId: widget.task?.recurrenceRuleId,
                                title: title.text,
                                priority: priority,
                                status: status,
                                dueAt: due,
                                scheduledStartAt: start,
                                scheduledEndAt: end,
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              ),
                              onChanged: (value) => reminderConfig = value,
                            ),
                        ],
                      ),
                      if (warning != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            warning,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                        ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              error!,
                              key: const Key('form-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('save-task'),
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(saving ? 'Đang lưu…' : 'Lưu công việc'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
