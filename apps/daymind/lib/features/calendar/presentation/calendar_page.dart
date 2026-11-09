import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/controller.dart';
import '../../recurrence/domain/recurrence.dart';
import '../../tasks/presentation/task_editor.dart';
import '../../tasks/domain/task.dart';
import '../domain/calendar.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late String zone =
      widget.controller.reminders?.preferences.timezoneId ?? 'UTC';
  late String selected = dateKey(
    tz.TZDateTime.from(widget.controller.now(), zoneLocation(zone)),
  );
  String mode = 'month';
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    final date = civilDate(selected);
    try {
      await widget.controller.calendarRange(
        dateKey(
          DateTime.utc(
            date.year,
            date.month,
            1,
          ).subtract(const Duration(days: 7)),
        ),
        dateKey(
          DateTime.utc(
            date.year,
            date.month + 1,
            1,
          ).add(const Duration(days: 7)),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void move(int delta) {
    final d = civilDate(selected);
    setState(
      () => selected = mode == 'month'
          ? dateKey(DateTime.utc(d.year, d.month + delta, 1))
          : addDate(selected, delta * (mode == 'week' ? 7 : 1)),
    );
    load();
  }

  String clock(DateTime value) {
    final d = tz.TZDateTime.from(value, zoneLocation(zone));
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget agenda(String day, List<CalendarEntry> all, Set<String> overlaps) {
    final entries = all.where((e) => e.occursOn(day, zone)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(day, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text('Chưa có lịch hoặc hạn hoàn thành trong ngày này.'),
          ),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: entry.task.status == TaskStatus.completed,
                      onChanged:
                          widget.controller.busy ||
                              entry.task.status == TaskStatus.cancelled
                          ? null
                          : (_) async {
                              try {
                                await widget.controller.toggle(entry.task);
                              } catch (e) {
                                if (mounted) setState(() => error = '$e');
                              }
                            },
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => showTaskEditor(context, task: entry.task),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.task.title,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entry.kind == CalendarEntryKind.deadline
                                    ? 'Hạn hoàn thành · ${clock(entry.at)}'
                                    : entry.kind == CalendarEntryKind.end
                                    ? 'Kết thúc lịch thực hiện · ${clock(entry.at)}'
                                    : 'Lịch thực hiện · ${clock(entry.at)}${entry.end == null ? '' : ' → ${clock(entry.end!)}${dateKey(tz.TZDateTime.from(entry.at, zoneLocation(zone))) == dateKey(tz.TZDateTime.from(entry.end!, zoneLocation(zone))) ? '' : ' (${dateKey(tz.TZDateTime.from(entry.end!, zoneLocation(zone)))})'}'}',
                              ),
                              if (entry.task.occurrenceId != null)
                                const Text(
                                  '↻ Một lần trong chuỗi',
                                  style: TextStyle(fontSize: 12),
                                ),
                              if (entry.kind == CalendarEntryKind.scheduled &&
                                  overlaps.contains(entry.task.id))
                                Text(
                                  'Có lịch trùng giờ · bạn vẫn có thể điều chỉnh',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .tertiary,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: entry.kind == CalendarEntryKind.deadline
                          ? 'Hạn hoàn thành'
                          : 'Lịch thực hiện',
                      child: Icon(
                        entry.kind == CalendarEntryKind.deadline
                            ? Icons.flag_outlined
                            : Icons.schedule,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = civilDate(selected),
        all = calendarEntries(widget.controller.visibleTasks);
    final overlaps = overlappingTasks(all);
    final first = DateTime.utc(date.year, date.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final weekStart = civilDate(selected)
        .subtract(Duration(days: date.weekday - 1));
    final zones = {
      zone,
      widget.controller.reminders?.preferences.timezoneId ?? 'UTC',
      'Asia/Ho_Chi_Minh',
      'UTC',
      ...widget.controller.recurrence.rules.map((r) => r.spec.zone),
    };
    return ListView(
      key: const Key('calendar-page'),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        Text('Lịch của bạn', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Dành chỗ cho điều quan trọng, cả những khoảng nghỉ.'),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const {
              'day': 'Ngày',
              'week': 'Tuần',
              'month': 'Tháng',
            }.entries)
              ChoiceChip(
                key: Key('calendar-${item.key}'),
                label: Text(item.value),
                selected: mode == item.key,
                onSelected: (_) => setState(() => mode = item.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: zone,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Múi giờ hiển thị'),
          items: [
            for (final z in zones) DropdownMenuItem(value: z, child: Text(z)),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => zone = value);
              load();
            }
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: loading ? null : () => move(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Khoảng trước',
            ),
            Expanded(
              child: Text(
                mode == 'month'
                    ? 'Tháng ${date.month} / ${date.year}'
                    : selected,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: loading ? null : () => move(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Khoảng sau',
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(
                () => selected = dateKey(
                  tz.TZDateTime.from(
                    widget.controller.now(),
                    zoneLocation(zone),
                  ),
                ),
              );
              load();
            },
            child: const Text('Về hôm nay'),
          ),
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (mode == 'month') ...[
          Row(
            children: [
              for (final label in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
                Expanded(child: Center(child: Text(label))),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent:
                  58 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, i) {
              final d = gridStart.add(Duration(days: i)), day = dateKey(d);
              final count = all.where((e) => e.occursOn(day, zone)).length;
              return Semantics(
                key: ValueKey('calendar-date-$day'),
                selected: selected == day,
                label: '$day, $count mốc lịch',
                child: Material(
                  color: selected == day
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () {
                      setState(() => selected = day);
                      if (d.month != date.month || d.year != date.year) load();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              color: d.month == date.month
                                  ? null
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          if (count > 0)
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        if (mode == 'week')
          for (var i = 0; i < 7; i++)
            agenda(dateKey(weekStart.add(Duration(days: i))), all, overlaps)
        else
          agenda(selected, all, overlaps),
      ],
    );
  }
}
