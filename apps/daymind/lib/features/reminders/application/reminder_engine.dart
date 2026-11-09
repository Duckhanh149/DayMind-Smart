import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/record_store.dart';
import '../../tasks/data/database.dart';
import '../../tasks/domain/task.dart' as domain;
import '../../recurrence/domain/recurrence.dart';
import '../domain/reminder.dart';

class ReminderEngine {
  ReminderEngine(this.db, this.scheduler, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now,
      records = RecordStore(db);
  final DaymindDatabase db;
  final RecordStore records;
  final NotificationScheduler scheduler;
  final DateTime Function() clock;
  static const policy = ReminderPolicy();
  Future<NotificationPreferences> preferences() async =>
      NotificationPreferences.fromJson(
        await records.get('notifications', 'settings') ?? {},
      );
  Future<List<ReminderRule>> rules(String taskId) async =>
      (await records.list('reminder_rules'))
          .where((x) => x['taskId'] == taskId)
          .map(ReminderRule.fromJson)
          .toList();
  Future<List<ReminderEventRecord>> events() => (db.select(
    db.reminderEvents,
  )..orderBy([(t) => OrderingTerm.desc(t.scheduledMs)])).get();
  Future<void> configure(NotificationPreferences value) async {
    value.validate();
    await records.put('notifications', 'settings', value.toJson());
  }

  Future<void> configureTask(
    String taskId,
    String mode,
    List<ReminderRule> rules,
  ) => db.transaction(() async {
    if (!['auto', 'off', 'custom'].contains(mode)) {
      throw const domain.ValidationException('Chế độ nhắc không hợp lệ.');
    }
    if (rules.length > 8 ||
        rules.map((r) => r.id).toSet().length != rules.length ||
        rules.any(
          (r) =>
              r.id.isEmpty || r.id == 'default' || r.id.startsWith('snooze:'),
        )) {
      throw const domain.ValidationException(
        'Mỗi việc hỗ trợ tối đa 8 mốc nhắc có mã riêng.',
      );
    }
    await records.put('task_reminders', taskId, {'id': taskId, 'mode': mode});
    for (final old in await this.rules(taskId)) {
      await records.remove('reminder_rules', old.id);
    }
    for (final rule in rules) {
      if (rule.taskId != taskId) {
        throw const domain.ValidationException(
          'Quy tắc không thuộc công việc này.',
        );
      }
      if (rule.offsetMinutes < 0 ||
          rule.offsetMinutes > 43200 ||
          (rule.kind == ReminderKind.absolute && rule.absoluteAt == null)) {
        throw const domain.ValidationException(
          'Giờ hoặc khoảng nhắc không hợp lệ.',
        );
      }
      await records.put('reminder_rules', rule.id, rule.toJson());
    }
  });
  Future<void> _state(
    ReminderEventRecord event,
    ReminderState state,
    String outcome,
  ) async {
    final at = clock().millisecondsSinceEpoch;
    await (db.update(
      db.reminderEvents,
    )..where((r) => r.eventKey.equals(event.eventKey))).write(
      ReminderEventsCompanion(state: Value(state.name), updatedMs: Value(at)),
    );
    await db
        .into(db.deliveryLogs)
        .insert(
          DeliveryLogsCompanion.insert(
            id: const Uuid().v4(),
            eventKey: event.eventKey,
            outcome: outcome,
            atMs: at,
          ),
        );
  }

  Future<void> reconcile(List<domain.Task> tasks) async {
    final now = clock(), prefs = await preferences();
    final permitted = prefs.primaryDevice && await scheduler.granted();
    final prior = await events();
    final byId = {for (final task in tasks) task.id: task};
    final modes = {
      for (final item in await records.list('task_reminders'))
        item['id'] as String: item['mode'] as String,
    };
    final allRules = (await records.list('reminder_rules'))
        .map(ReminderRule.fromJson)
        .toList();
    final effectiveByTask = <String, List<ReminderRule>>{};
    final off = <String>{};
    for (final task in tasks) {
      final configId =
          [
            task.occurrenceId,
            task.recurrenceRuleId,
            task.reminderTaskId,
          ].whereType<String>().where(modes.containsKey).firstOrNull ??
          task.reminderTaskId;
      final mode = modes[configId] ?? 'auto';
      if (mode == 'off') off.add(task.id);
      final fallback = policy.defaultRule(task, prefs);
      effectiveByTask[task.id] = mode == 'off'
          ? []
          : mode == 'custom'
          ? allRules.where((r) => r.taskId == configId && r.enabled).toList()
          : fallback == null
          ? []
          : [fallback];
    }
    for (final old in prior.where(
      (e) => ['planned', 'scheduled'].contains(e.state),
    )) {
      final task = byId[old.occurrenceId ?? old.taskId];
      final invalid =
          task == null ||
          task.terminal ||
          task.deletedAt != null ||
          off.contains(task.id) ||
          task.reminderRevision != old.taskRevision ||
          (old.occurrenceId != null &&
              task.revision != old.occurrenceRevision) ||
          (!old.ruleId.startsWith('snooze:') &&
              !(effectiveByTask[task.id] ?? []).any((r) => r.id == old.ruleId));
      if (invalid || now.millisecondsSinceEpoch > old.expiresMs) {
        await scheduler.cancel(old.platformId);
        await _state(
          old,
          invalid ? ReminderState.cancelled : ReminderState.expired,
          invalid ? 'invalidated' : 'expired',
        );
      } else if (!permitted && old.state == 'scheduled') {
        await scheduler.cancel(old.platformId);
        await _state(
          old,
          ReminderState.planned,
          'permission_or_device_suppressed',
        );
      }
    }
    for (final task in tasks.where((t) => !t.terminal && t.deletedAt == null)) {
      final effective = effectiveByTask[task.id] ?? [];
      for (final rule in effective) {
        // One default slot per task revision: resuming/permission changes cannot create a second deadline fallback.
        final history = prior
            .where(
              (e) =>
                  e.taskId == task.reminderTaskId &&
                  e.taskRevision == task.reminderRevision &&
                  e.occurrenceId == task.occurrenceId &&
                  (task.occurrenceId == null ||
                      e.occurrenceRevision == task.revision) &&
                  e.ruleId == rule.id,
            )
            .toList();
        if (history.any(
          (e) =>
              ['unknown', 'dismissed', 'snoozed', 'expired'].contains(e.state),
        )) {
          continue;
        }
        if (history.any((e) => e.scheduledMs <= now.millisecondsSinceEpoch)) {
          continue;
        }
        final plan = policy.plan(task, rule, prefs, now);
        if (plan == null) continue;
        for (final obsolete in history.where(
          (e) =>
              e.eventKey != plan.key &&
              ['planned', 'scheduled', 'suppressed'].contains(e.state),
        )) {
          await scheduler.cancel(obsolete.platformId);
          await _state(obsolete, ReminderState.cancelled, 'rule_changed');
        }
        final present = prior.where((e) => e.eventKey == plan.key).firstOrNull;
        if (plan.suppressed &&
            present != null &&
            present.state == 'scheduled') {
          await scheduler.cancel(present.platformId);
          await _state(present, ReminderState.suppressed, 'quiet_hours');
          continue;
        }
        if (present != null &&
            !['planned', 'suppressed', 'cancelled'].contains(present.state)) {
          continue;
        }
        if (present == null) {
          await db
              .into(db.reminderEvents)
              .insert(
                ReminderEventsCompanion.insert(
                  eventKey: plan.key,
                  taskId: task.reminderTaskId,
                  ruleId: rule.id,
                  occurrenceId: Value(task.occurrenceId ?? rule.occurrenceId),
                  occurrenceRevision: Value(
                    task.occurrenceId == null ? null : task.revision,
                  ),
                  taskRevision: task.reminderRevision,
                  scheduledMs: plan.at.millisecondsSinceEpoch,
                  expiresMs: plan.expiresAt.millisecondsSinceEpoch,
                  state: plan.suppressed ? 'suppressed' : 'planned',
                  title: task.title,
                  priority: task.priority.index,
                  updatedMs: now.millisecondsSinceEpoch,
                ),
              );
        } else {
          await (db.update(
            db.reminderEvents,
          )..where((e) => e.eventKey.equals(plan.key))).write(
            ReminderEventsCompanion(
              state: Value(plan.suppressed ? 'suppressed' : 'planned'),
            ),
          );
        }
      }
    }
    if (permitted) {
      final candidates =
          await (db.select(db.reminderEvents)
                ..where(
                  (e) =>
                      e.state.isIn(['planned', 'scheduled']) &
                      e.scheduledMs.isBiggerThanValue(
                        now.millisecondsSinceEpoch,
                      ),
                )
                ..orderBy([(e) => OrderingTerm.asc(e.scheduledMs)]))
              .get();
      for (final event
          in candidates.skip(128).where((e) => e.state == 'scheduled')) {
        await scheduler.cancel(event.platformId);
        await _state(event, ReminderState.planned, 'outside_window');
      }
      for (final event
          in candidates.take(128).where((e) => e.state == 'planned')) {
        try {
          await scheduler.schedule(
            id: event.platformId,
            eventKey: event.eventKey,
            at: DateTime.fromMillisecondsSinceEpoch(
              event.scheduledMs,
              isUtc: true,
            ),
          );
          await _state(event, ReminderState.scheduled, 'scheduled');
        } catch (_) {
          await _state(event, ReminderState.planned, 'schedule_failed');
        }
      }
    }
    await (db.delete(db.deliveryLogs)..where(
          (l) => l.atMs.isSmallerThanValue(
            now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
          ),
        ))
        .go();
  }

  Future<void> dismiss(ReminderEventRecord event) async {
    await scheduler.cancel(event.platformId);
    await _state(event, ReminderState.dismissed, 'dismissed');
    await markRead(event.eventKey);
  }

  Future<void> markRead(String key) async {
    await (db.update(db.reminderEvents)..where((e) => e.eventKey.equals(key)))
        .write(const ReminderEventsCompanion(read: Value(true)));
  }

  Future<void> snooze(
    ReminderEventRecord event,
    domain.Task task,
    DateTime until,
  ) async {
    if (task.terminal ||
        task.deletedAt != null ||
        task.reminderRevision != event.taskRevision ||
        task.occurrenceId != event.occurrenceId ||
        (task.occurrenceId != null &&
            task.revision != event.occurrenceRevision) ||
        !until.isAfter(clock()) ||
        until.difference(clock()) > const Duration(days: 30)) {
      throw const domain.ValidationException(
        'Hãy chọn giờ hoãn trong 30 ngày tới cho công việc còn hiệu lực.',
      );
    }
    final rule = ReminderRule(
      id: 'snooze:${event.eventKey}',
      taskId: task.reminderTaskId,
      kind: ReminderKind.absolute,
      absoluteAt: until,
      occurrenceId: event.occurrenceId,
    );
    final plan = policy.plan(task, rule, await preferences(), clock())!;
    await scheduler.cancel(event.platformId);
    await db.transaction(() async {
      final latest = await (db.select(
        db.reminderEvents,
      )..where((e) => e.eventKey.equals(event.eventKey))).getSingle();
      if ([
        'snoozed',
        'cancelled',
        'expired',
        'dismissed',
      ].contains(latest.state)) {
        return;
      }
      final root = await (db.select(
        db.tasks,
      )..where((t) => t.id.equals(event.taskId))).getSingleOrNull();
      if (root == null ||
          root.deletedAt != null ||
          [2, 3].contains(root.status) ||
          root.revision != event.taskRevision ||
          !await _occurrenceValid(event)) {
        throw const domain.ValidationException(
          'Công việc vừa thay đổi; không tạo lại nhắc cũ.',
        );
      }
      await _state(event, ReminderState.snoozed, 'snoozed');
      await db
          .into(db.reminderEvents)
          .insert(
            ReminderEventsCompanion.insert(
              eventKey: plan.key,
              taskId: task.reminderTaskId,
              ruleId: rule.id,
              occurrenceId: Value(event.occurrenceId),
              occurrenceRevision: Value(event.occurrenceRevision),
              taskRevision: task.reminderRevision,
              scheduledMs: plan.at.millisecondsSinceEpoch,
              expiresMs: plan.expiresAt.millisecondsSinceEpoch,
              state: plan.suppressed ? 'suppressed' : 'planned',
              title: task.title,
              priority: task.priority.index,
              updatedMs: clock().millisecondsSinceEpoch,
            ),
          );
    });
  }

  Future<bool> _occurrenceValid(ReminderEventRecord event) async {
    if (event.occurrenceId == null) return true;
    final json = await records.get('occurrences', event.occurrenceId!);
    if (json == null) return false;
    final o = TaskOccurrence.fromJson(json);
    return o.taskId == event.taskId &&
        !o.deleted &&
        !o.terminal &&
        o.revision == event.occurrenceRevision;
  }

  /// Used by guarded foreground schedulers. Android independently enforces these checks in its receiver.
  Future<List<ReminderEventRecord>> claimDue(List<domain.Task> tasks) async {
    final prefs = await preferences(), now = clock();
    final permission = await scheduler.granted();
    return db.transaction(() async {
      final result = <ReminderEventRecord>[];
      final taskMap = {for (final task in tasks) task.id: task};
      for (final event in await events()) {
        if (event.state != 'scheduled' ||
            event.scheduledMs > now.millisecondsSinceEpoch) {
          continue;
        }
        final task = taskMap[event.occurrenceId ?? event.taskId];
        final current = await (db.select(
          db.tasks,
        )..where((t) => t.id.equals(event.taskId))).getSingleOrNull();
        if (task == null ||
            current == null ||
            current.revision != event.taskRevision ||
            current.deletedAt != null ||
            [2, 3].contains(current.status) ||
            task.terminal ||
            task.deletedAt != null ||
            task.reminderRevision != event.taskRevision ||
            (event.occurrenceId != null &&
                task.revision != event.occurrenceRevision) ||
            !await _occurrenceValid(event)) {
          await _state(event, ReminderState.cancelled, 'invalidated');
          continue;
        }
        if (event.expiresMs < now.millisecondsSinceEpoch) {
          await _state(event, ReminderState.expired, 'expired');
          continue;
        }
        if (!prefs.primaryDevice || prefs.quietAt(now) || !permission) {
          await _state(event, ReminderState.suppressed, 'quiet_or_permission');
          continue;
        }
        await _state(event, ReminderState.unknown, 'display_attempt');
        result.add(event);
      }
      return result;
    });
  }
}
