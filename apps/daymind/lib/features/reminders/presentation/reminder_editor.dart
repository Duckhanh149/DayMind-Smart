import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../tasks/domain/task.dart';
import '../application/reminder_engine.dart';
import '../domain/reminder.dart';

class ReminderEditor extends StatefulWidget {
  const ReminderEditor({
    super.key,
    required this.engine,
    required this.task,
    required this.onChanged,
  });
  final ReminderEngine engine;
  final Task task;
  final ValueChanged<TaskReminderConfig> onChanged;
  @override
  State<ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<ReminderEditor> {
  String mode = 'auto';
  List<ReminderRule> rules = [];
  bool loading = true;
  NotificationPreferences preferences = const NotificationPreferences();
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      Map<String, dynamic>? saved;
      var configId = widget.task.id;
      for (final id in [
        widget.task.id,
        widget.task.recurrenceRuleId,
        widget.task.seriesId,
      ].whereType<String>()) {
        saved = await widget.engine.records.get('task_reminders', id);
        if (saved != null) {
          configId = id;
          break;
        }
      }
      final savedRules = await widget.engine.rules(configId);
      final prefs = await widget.engine.preferences();
      if (mounted) {
        setState(() {
          mode = saved?['mode'] as String? ?? 'auto';
          rules = savedRules;
          preferences = prefs;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  void changed() {
    widget.onChanged(TaskReminderConfig(mode, [...rules]));
  }

  void update(
    ReminderRule rule, {
    ReminderKind? kind,
    int? offset,
    DateTime? absoluteAt,
  }) {
    setState(
      () => rules = rules
          .map(
            (r) => r.id == rule.id
                ? ReminderRule(
                    id: r.id,
                    taskId: widget.task.id,
                    kind: kind ?? r.kind,
                    offsetMinutes: offset ?? r.offsetMinutes,
                    absoluteAt: absoluteAt ?? r.absoluteAt,
                    revision: r.revision + 1,
                  )
                : r,
          )
          .toList(),
    );
    changed();
  }

  Future<void> date(ReminderRule rule) async {
    final initial =
        (rule.absoluteAt ?? DateTime.now().add(const Duration(hours: 1)))
            .toLocal();
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time != null) {
      update(
        rule,
        absoluteAt: DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ).toUtc(),
      );
    }
  }

  String preview(ReminderRule rule) {
    final plan = const ReminderPolicy().plan(
      widget.task,
      rule,
      preferences,
      DateTime.now(),
    );
    if (plan == null) {
      return 'Chưa có mốc phù hợp hoặc thời điểm đã qua; không phát lại nhắc cũ.';
    }
    if (plan.suppressed) return 'Không phát: thời điểm nằm trong giờ yên lặng.';
    final local = plan.at.toLocal();
    return 'Dự kiến ${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} · tùy quyền và khả năng nền của thiết bị.';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      );
    }
    if (error != null) return Text('Không đọc được cài đặt nhắc: $error');
    final fallback = const ReminderPolicy().defaultRule(
      widget.task,
      preferences,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: mode,
          decoration: const InputDecoration(labelText: 'Nhắc việc'),
          items: const [
            DropdownMenuItem(value: 'auto', child: Text('Theo cài đặt chung')),
            DropdownMenuItem(value: 'off', child: Text('Tắt cho việc này')),
            DropdownMenuItem(value: 'custom', child: Text('Đặt nhắc riêng')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => mode = value);
              changed();
            }
          },
        ),
        const SizedBox(height: 8),
        if (mode == 'auto')
          Text(
            fallback == null
                ? 'Không có nhắc tự động cho việc này.'
                : preview(fallback),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (mode == 'custom') ...[
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<ReminderKind>(
                          isExpanded: true,
                          initialValue: rule.kind,
                          decoration: const InputDecoration(
                            labelText: 'Mốc nhắc',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: ReminderKind.due,
                              child: Text('Trước hạn'),
                            ),
                            DropdownMenuItem(
                              value: ReminderKind.start,
                              child: Text('Trước giờ bắt đầu'),
                            ),
                            DropdownMenuItem(
                              value: ReminderKind.absolute,
                              child: Text('Ngày giờ riêng'),
                            ),
                          ],
                          onChanged: (kind) {
                            if (kind != null) update(rule, kind: kind);
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Xóa mốc nhắc',
                        onPressed: () {
                          setState(
                            () => rules.removeWhere((r) => r.id == rule.id),
                          );
                          changed();
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (rule.kind == ReminderKind.absolute)
                    OutlinedButton(
                      onPressed: () => date(rule),
                      child: Text(
                        rule.absoluteAt == null
                            ? 'Chọn ngày giờ'
                            : rule.absoluteAt!.toLocal().toString(),
                      ),
                    )
                  else
                    TextFormField(
                      key: ValueKey('offset-${rule.id}'),
                      initialValue: '${rule.offsetMinutes}',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Trước bao nhiêu phút? (0 = đúng mốc)',
                      ),
                      onChanged: (v) =>
                          update(rule, offset: int.tryParse(v) ?? -1),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    rule.offsetMinutes < 0 || rule.offsetMinutes > 43200
                        ? 'Khoảng nhắc cần từ 0 đến 43.200 phút.'
                        : preview(rule),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          if (rules.length < 8)
            TextButton.icon(
              onPressed: () {
                setState(
                  () => rules.add(
                    ReminderRule(id: const Uuid().v4(), taskId: widget.task.id),
                  ),
                );
                changed();
              },
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Thêm mốc nhắc'),
            ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
