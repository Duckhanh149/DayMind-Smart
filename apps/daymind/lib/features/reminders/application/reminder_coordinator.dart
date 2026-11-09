import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../tasks/data/database.dart';
import '../../tasks/domain/task.dart' as domain;
import '../../../platform/notification_scheduler.dart';
import '../domain/reminder.dart';
import 'reminder_engine.dart';

class ReminderCoordinator extends ChangeNotifier with WidgetsBindingObserver {
  ReminderCoordinator(
    this.engine,
    this.getTasks, {
    this.onNativeChange,
    this.onInApp,
  });
  final ReminderEngine engine;
  final Future<List<domain.Task>> Function() getTasks;
  final Future<void> Function()? onNativeChange;
  final void Function(String)? onInApp;
  NotificationPreferences preferences = const NotificationPreferences();
  List<ReminderEventRecord> events = [];
  bool granted = false, _foreground = true, _running = false, _disposed = false;
  String? error;
  Timer? _timer;
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
    if (_running || _disposed) return;
    _running = true;
    try {
      preferences = await engine.preferences();
      granted = await engine.scheduler.granted();
      final tasks = await getTasks();
      if (replan) await engine.reconcile(tasks);
      if (!Platform.isAndroid) {
        final due = await engine.claimDue(tasks);
        if (due.isNotEmpty) {
          final sorted = [...due]
            ..sort((a, b) => b.priority.compareTo(a.priority));
          if (_foreground) {
            onInApp?.call(sorted.first.title);
          } else {
            final id =
                1000000000 +
                DateTime.now().millisecondsSinceEpoch ~/
                    (preferences.groupingMinutes * 60000) %
                    1000000000;
            await engine.scheduler.show(
              id: id,
              title: due.length == 1
                  ? due.single.title
                  : '${due.length} công việc cần nhắc',
              body: sorted.take(7).map((e) => e.title).join('\n'),
              eventKey: sorted.first.eventKey,
            );
          }
        }
      }
      events = await engine.events();
      error = null;
    } catch (e) {
      error = '$e';
    } finally {
      _running = false;
      if (!_disposed) notifyListeners();
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
        .where((t) => t.id == event.taskId)
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
    }
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
