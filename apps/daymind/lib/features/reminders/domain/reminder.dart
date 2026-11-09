import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../tasks/domain/task.dart';

tz.Location timeLocation(String id) =>
    id == 'UTC' ? tz.UTC : tz.getLocation(id);

enum ReminderKind { due, start, absolute }

enum ReminderPreset { minimal, normal, custom }

enum ReminderState {
  planned,
  scheduled,
  unknown,
  dismissed,
  snoozed,
  cancelled,
  suppressed,
  expired,
}

class TaskReminderConfig {
  const TaskReminderConfig(this.mode, this.rules);
  final String mode;
  final List<ReminderRule> rules;
  List<ReminderRule> forTask(String taskId) => rules
      .map(
        (r) => ReminderRule(
          id: r.id,
          taskId: taskId,
          kind: r.kind,
          offsetMinutes: r.offsetMinutes,
          absoluteAt: r.absoluteAt,
          enabled: r.enabled,
          revision: r.revision,
        ),
      )
      .toList();
}

class NotificationPreferences {
  const NotificationPreferences({
    this.preset = ReminderPreset.normal,
    this.quietEnabled = true,
    this.quietStart = 22 * 60,
    this.quietEnd = 7 * 60,
    this.timezoneId = 'UTC',
    this.defaultOffsetMinutes = 15,
    this.permissionPrompted = false,
    this.primaryDevice = true,
    this.groupingMinutes = 10,
    this.digestEnabled = false,
    this.digestMinute = 7 * 60,
  });
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        preset:
            ReminderPreset.values
                .where((x) => x.name == json['preset'])
                .firstOrNull ??
            ReminderPreset.normal,
        quietEnabled: json['quietEnabled'] != false,
        quietStart: (json['quietStart'] as num?)?.toInt() ?? 1320,
        quietEnd: (json['quietEnd'] as num?)?.toInt() ?? 420,
        timezoneId: json['timezoneId'] as String? ?? 'UTC',
        defaultOffsetMinutes:
            (json['defaultOffsetMinutes'] as num?)?.toInt() ?? 15,
        permissionPrompted: json['permissionPrompted'] == true,
        primaryDevice: json['primaryDevice'] != false,
        groupingMinutes: (json['groupingMinutes'] as num?)?.toInt() ?? 10,
        digestEnabled: json['digestEnabled'] == true,
        digestMinute: (json['digestMinute'] as num?)?.toInt() ?? 420,
      );
  final ReminderPreset preset;
  final bool quietEnabled, permissionPrompted, primaryDevice, digestEnabled;
  final int quietStart,
      quietEnd,
      defaultOffsetMinutes,
      groupingMinutes,
      digestMinute;
  final String timezoneId;
  Map<String, dynamic> toJson() => {
    'preset': preset.name,
    'quietEnabled': quietEnabled,
    'quietStart': quietStart,
    'quietEnd': quietEnd,
    'timezoneId': timezoneId,
    'defaultOffsetMinutes': defaultOffsetMinutes,
    'permissionPrompted': permissionPrompted,
    'primaryDevice': primaryDevice,
    'groupingMinutes': groupingMinutes,
    'digestEnabled': digestEnabled,
    'digestMinute': digestMinute,
  };
  void validate() {
    if ([quietStart, quietEnd, digestMinute].any((x) => x < 0 || x > 1439) ||
        defaultOffsetMinutes < 0 ||
        defaultOffsetMinutes > 43200 ||
        groupingMinutes < 1 ||
        groupingMinutes > 60) {
      throw const ValidationException('Thiết lập giờ nhắc không hợp lệ.');
    }
    if (quietEnabled && quietStart == quietEnd) {
      throw const ValidationException(
        'Giờ bắt đầu và kết thúc yên lặng phải khác nhau.',
      );
    }
    timeLocation(timezoneId);
  }

  bool quietAt(DateTime instant) {
    if (!quietEnabled) return false;
    final local = tz.TZDateTime.from(instant, timeLocation(timezoneId));
    final minute = local.hour * 60 + local.minute;
    return quietStart > quietEnd
        ? minute >= quietStart || minute < quietEnd
        : minute >= quietStart && minute < quietEnd;
  }

  DateTime quietEndAfter(DateTime instant) {
    final local = tz.TZDateTime.from(instant, timeLocation(timezoneId));
    var end = tz.TZDateTime(
      local.location,
      local.year,
      local.month,
      local.day,
      quietEnd ~/ 60,
      quietEnd % 60,
    );
    if (!end.isAfter(local)) {
      end = tz.TZDateTime(
        local.location,
        local.year,
        local.month,
        local.day + 1,
        quietEnd ~/ 60,
        quietEnd % 60,
      );
    }
    return end.toUtc();
  }
}

class ReminderRule {
  const ReminderRule({
    required this.id,
    required this.taskId,
    this.kind = ReminderKind.due,
    this.offsetMinutes = 15,
    this.absoluteAt,
    this.enabled = true,
    this.revision = 1,
    this.occurrenceId,
  });
  factory ReminderRule.fromJson(Map<String, dynamic> json) => ReminderRule(
    id: json['id'] as String,
    taskId: json['taskId'] as String,
    kind: ReminderKind.values.byName(json['kind'] as String),
    offsetMinutes: json['offsetMinutes'] as int? ?? 0,
    absoluteAt: json['absoluteAt'] == null
        ? null
        : DateTime.parse(json['absoluteAt'] as String).toUtc(),
    enabled: json['enabled'] != false,
    revision: json['revision'] as int? ?? 1,
    occurrenceId: json['occurrenceId'] as String?,
  );
  final String id, taskId;
  final ReminderKind kind;
  final int offsetMinutes, revision;
  final bool enabled;
  final DateTime? absoluteAt;
  final String? occurrenceId;
  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'kind': kind.name,
    'offsetMinutes': offsetMinutes,
    'absoluteAt': absoluteAt?.toUtc().toIso8601String(),
    'enabled': enabled,
    'revision': revision,
    'occurrenceId': occurrenceId,
  };
}

class ReminderPlan {
  const ReminderPlan({
    required this.key,
    required this.task,
    required this.rule,
    required this.at,
    required this.expiresAt,
    this.suppressed = false,
  });
  final String key;
  final Task task;
  final ReminderRule rule;
  final DateTime at, expiresAt;
  final bool suppressed;
}

class ReminderPolicy {
  const ReminderPolicy();
  ReminderRule? defaultRule(Task task, NotificationPreferences prefs) {
    if (prefs.preset == ReminderPreset.minimal || task.dueAt == null) {
      return null;
    }
    return ReminderRule(
      id: 'default',
      taskId: task.id,
      offsetMinutes: prefs.preset == ReminderPreset.custom
          ? prefs.defaultOffsetMinutes
          : switch (task.priority) {
              TaskPriority.high => 30,
              TaskPriority.medium => 15,
              TaskPriority.low => 0,
            },
    );
  }

  ReminderPlan? plan(
    Task task,
    ReminderRule rule,
    NotificationPreferences prefs,
    DateTime now,
  ) {
    if (task.deletedAt != null || task.terminal || !rule.enabled) return null;
    if (rule.offsetMinutes < 0 || rule.offsetMinutes > 43200) {
      throw const ValidationException('Khoảng nhắc cần từ 0 đến 43.200 phút.');
    }
    final anchor = switch (rule.kind) {
      ReminderKind.due => task.dueAt,
      ReminderKind.start => task.scheduledStartAt,
      ReminderKind.absolute => rule.absoluteAt,
    };
    if (anchor == null) return null;
    var at = rule.kind == ReminderKind.absolute
        ? anchor.toUtc()
        : anchor.subtract(Duration(minutes: rule.offsetMinutes)).toUtc();
    // Creating/importing overdue tasks never replays a historical reminder.
    if (!at.isAfter(now)) {
      if (rule.id == 'default' && anchor.isAfter(now)) {
        at = anchor.toUtc();
      } else {
        return null;
      }
    }
    final expires = rule.kind == ReminderKind.due && at.isBefore(anchor)
        ? anchor.toUtc()
        : at.add(const Duration(minutes: 15));
    var suppressed = false;
    if (prefs.quietAt(at)) {
      final permitted = prefs.quietEndAfter(at);
      final quietLimit = rule.kind == ReminderKind.due ? anchor : expires;
      if (!permitted.isAfter(quietLimit)) {
        at = permitted;
      } else {
        suppressed = true;
      }
    }
    final key = sha256
        .convert(
          utf8.encode(
            '${task.id}|${rule.occurrenceId ?? 'once'}|${rule.id}|${at.millisecondsSinceEpoch}|${task.revision}:${rule.revision}',
          ),
        )
        .toString();
    return ReminderPlan(
      key: key,
      task: task,
      rule: rule,
      at: at,
      expiresAt: expires,
      suppressed: suppressed,
    );
  }
}

abstract interface class NotificationScheduler {
  bool get supportsClosedApp;
  Future<bool> granted();
  Future<bool> requestPermission();
  Future<void> schedule({
    required int id,
    required String eventKey,
    required DateTime at,
  });
  Future<void> cancel(int id);
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? eventKey,
  });
}
