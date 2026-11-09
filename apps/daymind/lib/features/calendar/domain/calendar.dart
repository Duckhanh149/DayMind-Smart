import '../../tasks/domain/task.dart';
import '../../recurrence/domain/recurrence.dart';

import 'package:timezone/timezone.dart' as tz;

enum CalendarEntryKind { scheduled, end, deadline }

class CalendarEntry {
  const CalendarEntry(this.task, this.kind, this.at, this.end);
  final Task task;
  final CalendarEntryKind kind;
  final DateTime at;
  final DateTime? end;
  bool occursOn(String day, String zone) {
    final start = dateKey(tz.TZDateTime.from(at, zoneLocation(zone)));
    final last = dateKey(
      tz.TZDateTime.from(
        end == null || !end!.isAfter(at)
            ? at
            : end!.subtract(const Duration(microseconds: 1)),
        zoneLocation(zone),
      ),
    );
    return day.compareTo(start) >= 0 && day.compareTo(last) <= 0;
  }
}

List<CalendarEntry> calendarEntries(List<Task> tasks) => [
  for (final t in tasks.where((t) => t.deletedAt == null)) ...[
    if (t.scheduledStartAt != null)
      CalendarEntry(
        t,
        CalendarEntryKind.scheduled,
        t.scheduledStartAt!,
        t.scheduledEndAt,
      ),
    if (t.scheduledStartAt == null && t.scheduledEndAt != null)
      CalendarEntry(t, CalendarEntryKind.end, t.scheduledEndAt!, null),
    if (t.dueAt != null)
      CalendarEntry(t, CalendarEntryKind.deadline, t.dueAt!, null),
  ],
]..sort((a, b) => a.at.compareTo(b.at));

Set<String> overlappingTasks(List<CalendarEntry> entries) {
  final scheduled = entries
      .where(
        (e) =>
            e.kind == CalendarEntryKind.scheduled &&
            !e.task.terminal &&
            e.end?.isAfter(e.at) == true,
      )
      .toList();
  final result = <String>{};
  for (var a = 0; a < scheduled.length; a++) {
    for (var b = a + 1; b < scheduled.length; b++) {
      final x = scheduled[a], y = scheduled[b];
      if (x.at.isBefore(y.end!) && y.at.isBefore(x.end!)) {
        result.addAll([x.task.id, y.task.id]);
      }
    }
  }
  return result;
}
