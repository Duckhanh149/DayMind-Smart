import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../tasks/data/database.dart';
import '../../tasks/domain/task.dart' as domain;
import '../../assistant/domain/daily_assistant.dart' show localDay;
import '../../../platform/notification_scheduler.dart';
import '../domain/reminder.dart';
import 'reminder_engine.dart';

class ReminderCoordinator extends ChangeNotifier with WidgetsBindingObserver {
  ReminderCoordinator(
    this.engine,
    this.getTasks, {
    this.onNativeChange,
    this.onInApp,
    this.readTimezone,
  });
  final ReminderEngine engine;
  final Future<List<domain.Task>> Function() getTasks;
  final Future<void> Function()? onNativeChange;
  final void Function(String)? onInApp;
  final Future<String> Function()? readTimezone;
  NotificationPreferences preferences = const NotificationPreferences();
  List<ReminderEventRecord> events = [];
  bool granted = false, _foreground = true, _running = false, _disposed = false;
  String? error, _plannedDay;
  Timer? _timer;
  bool _windowVisible = true, _pendingReplan = false;
  void setWindowVisible(bool visible) {
    _windowVisible = visible;
    if (visible) unawaited(reloadFromNative());
  }

  Future<void> start(String zone) async {
    final stored = await engine.records.get('notifications', 'settings');
    if (zone.isEmpty) {
      error = 'Chưa xác định được múi giờ thiết bị. Nhắc việc tạm dừng; hãy kiểm tra múi giờ hệ thống và mở lại ứng dụng.';
      return;
    }
    preferences = NotificationPreferences.fromJson({
      ...?stored,
      'timezoneId': zone,
    });
    await engine.configure(preferences);
    if (engine.scheduler is PlatformNotificationScheduler) {
      (engine.scheduler as PlatformNotificationScheduler).onInApp = onInApp;
      (engine.scheduler as PlatformNotificationScheduler).onChanged = () {
        unawaited(reloadFromNative());
      };
    }
    WidgetsBinding.instance.addObserver(this);
    await refresh();
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => refresh(replan: false),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(reloadFromNative());
    }
  }

  Future<void> reloadFromNative() async {
    if (_disposed) return;
    try {
      await onNativeChange?.call();
      await refresh();
    } catch (e) {
      error = '$e';
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> refresh({bool replan = true}) async {
    if (_disposed) return;
    if (_running) {
      _pendingReplan = _pendingReplan || replan;
      return;
    }
    _running = true;
    try {
      preferences = await engine.preferences();
      if (readTimezone != null) {
        final zone = await readTimezone!();
        timeLocation(zone);
        if (zone != preferences.timezoneId) {
          preferences = NotificationPreferences.fromJson({
            ...preferences.toJson(),
            'timezoneId': zone,
          });
          await engine.configure(preferences);
          replan = true;
        }
      }
      granted = await engine.scheduler.granted();
      final tasks = await getTasks();
      final day = localDay(engine.clock(), preferences.timezoneId);
      if (replan || _plannedDay != day) {
        await engine.reconcile(tasks);
        _plannedDay = day;
      }
      if (!Platform.isAndroid) {
        final due = await engine.claimDue(tasks);
        if (_disposed) return;
        final digests = due.where((e) => e.ruleId == 'digest').toList();
        for (final digest in digests) {
          if (_foreground && _windowVisible) {
            onInApp?.call(digest.title);
          } else {
            await engine.scheduler.show(
              id: 999999999,
              title: 'Nhịp ngày mới',
              body: digest.title,
              eventKey: digest.eventKey,
            );
          }
        }
        final work = due.where((e) => e.ruleId != 'digest').toList()
          ..sort((a, b) => b.priority.compareTo(a.priority));
        if (work.isNotEmpty && !_disposed) {
          if (_foreground && _windowVisible) {
            onInApp?.call('Đến giờ: ${work.first.title}');
          } else {
            final window = preferences.groupingMinutes * 60000,
                stamp = engine.clock().millisecondsSinceEpoch;
            final start = stamp ~/ window * window;
            final group = await engine.groupForWindow(
              tasks,
              start,
              start + window,
            );
            if (_disposed || group.isEmpty) return;
            final id = 1000000000 + start ~/ window % 1000000000;
            await engine.scheduler.show(
              id: id,
              title: group.length == 1
                  ? group.single.title
                  : '${group.any((e) => e.priority == 2) ? 'Ưu tiên cao · ' : ''}${group.length} công việc cần nhắc',
              body: group.take(7).map((e) => e.title).join('\n'),
              eventKey: group.first.eventKey,
            );
          }
        }
      }
      events = await engine.events();
      error = engine.scheduler is PlatformNotificationScheduler
          ? (engine.scheduler as PlatformNotificationScheduler)
                .initializationError
          : null;
    } catch (e) {
      error = '$e';
    } finally {
      _running = false;
      if (!_disposed) notifyListeners();
      if (_pendingReplan && !_disposed) {
        _pendingReplan = false;
        unawaited(refresh());
      }
    }
  }

  Future<void> configure(Map<String, dynamic> changes) async {
    final latest = await engine.preferences();
    final value = NotificationPreferences.fromJson({
      ...latest.toJson(),
      ...changes,
    });
    await engine.configure(value);
    await refresh();
  }

  Future<void> requestPermission() async {
    if (preferences.permissionPrompted && !granted) {
      if (engine.scheduler is PlatformNotificationScheduler) {
        await (engine.scheduler as PlatformNotificationScheduler)
            .openSettings();
      }
      return;
    }
    await configure({'permissionPrompted': true});
    await engine.scheduler.requestPermission();
    await refresh();
  }

  Future<void> dismiss(ReminderEventRecord event) async {
    await engine.dismiss(event);
    await refresh();
  }

  Future<void> snooze(ReminderEventRecord event, Duration duration) async {
    final task = (await getTasks())
        .where((t) => t.id == (event.occurrenceId ?? event.taskId))
        .firstOrNull;
    if (task == null) {
      throw const domain.ValidationException('Công việc không còn tồn tại.');
    }
    await engine.snooze(event, task, engine.clock().add(duration));
    await refresh();
  }

  Future<void> markRead(ReminderEventRecord event) async {
    await engine.markRead(event.eventKey);
    await refresh(replan: false);
  }

  Future<void> test() async {
    if (!granted) {
      throw const domain.ValidationException(
        'Hãy cho phép thông báo trong cài đặt trước.',
      );
    }
    await engine.scheduler.show(
      id: 2147483646,
      title: 'Thử thông báo DayMind',
      body: 'Thông báo thử im lặng do bạn yêu cầu.',
    );
  }

  String localTime(int millis) {
    final date = tz.TZDateTime.fromMillisecondsSinceEpoch(
      timeLocation(preferences.timezoneId),
      millis,
    );
    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _disposed = true;
    if (engine.scheduler is PlatformNotificationScheduler) {
      (engine.scheduler as PlatformNotificationScheduler).onChanged = null;
      (engine.scheduler as PlatformNotificationScheduler).onInApp = null;
      (engine.scheduler as PlatformNotificationScheduler).onOpen = null;
    }
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
