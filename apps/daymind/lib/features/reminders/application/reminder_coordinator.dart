import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../tasks/data/database.dart';
import '../../tasks/domain/task.dart' as domain;
import '../../assistant/domain/daily_assistant.dart' show localDay;
import '../../../platform/notification_scheduler.dart';
import '../domain/reminder.dart';
import '../domain/notification_diagnostics.dart';
import '../../companion/domain/companion.dart';
import 'reminder_engine.dart';

class ReminderCoordinator extends ChangeNotifier with WidgetsBindingObserver {
  ReminderCoordinator(
    this.engine,
    this.getTasks, {
    this.onNativeChange,
    this.onInApp,
    this.onCue,
    this.readTimezone,
  });
  final _diagnostics = NotificationDiagnostics();
  NotificationDiagnostics get diagnostics =>
      engine.scheduler is PlatformNotificationScheduler
      ? (engine.scheduler as PlatformNotificationScheduler).diagnostics
      : _diagnostics;
  final ReminderEngine engine;
  final Future<List<domain.Task>> Function() getTasks;
  final Future<void> Function()? onNativeChange;
  final void Function(String)? onInApp;
  final void Function(CompanionCue)? onCue;
  void _announce(CompanionCue cue) {
    if (onCue != null) {
      onCue!(cue);
    } else {
      onInApp?.call(cue.announcement);
    }
  }

  final Future<String> Function()? readTimezone;
  Future<void> Function(bool)? onPrimaryRequest;
  Completer<void>? _idle;
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
      (engine.scheduler as PlatformNotificationScheduler).onForegroundCue =
          _announce;
      (engine.scheduler as PlatformNotificationScheduler).onInApp = (text) =>
          _announce(
            CompanionCue(
              CompanionEvent.reminderDue,
              'Đến giờ: $text',
              task: text,
            ),
          );
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
      diagnostics.record(NotificationDiagnosticCode.pollFailed);
      error = 'Chưa cập nhật được lịch nhắc. Kiểm tra quyền, múi giờ và kết nối dữ liệu trên thiết bị.';
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
    _idle = Completer<void>();
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
      if (preferences.quietAt(engine.clock())) {
        diagnostics.record(NotificationDiagnosticCode.quietHours);
      }
      if (!preferences.primaryDevice) {
        diagnostics.record(NotificationDiagnosticCode.secondaryDevice);
      }
      if (_disposed) return;
      final tasks = await getTasks();
      if (_disposed) return;
      final day = localDay(engine.clock(), preferences.timezoneId);
      if (replan || _plannedDay != day) {
        await engine.reconcile(tasks);
        _plannedDay = day;
      }
      if (_disposed) return;
      if (!Platform.isAndroid) {
        final due = await engine.claimDue(tasks);
        if (_disposed) return;
        final digests = due.where((e) => e.ruleId == 'digest').toList();
        for (final digest in digests) {
          if (_disposed) return;
          if (_foreground && _windowVisible) {
            diagnostics.record(NotificationDiagnosticCode.foregroundRoute);
            _announce(
              CompanionCue(
                CompanionEvent.dailyDigest,
                digest.title,
                summary: digest.title,
              ),
            );
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
            diagnostics.record(NotificationDiagnosticCode.foregroundRoute);
            _announce(
              CompanionCue(
                CompanionEvent.reminderDue,
                'Đến giờ: ${work.first.title}',
                task: work.first.title,
              ),
            );
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
      diagnostics.record(NotificationDiagnosticCode.pollFailed);
      error = 'Chưa cập nhật được lịch nhắc. Kiểm tra quyền, múi giờ và kết nối dữ liệu trên thiết bị.';
    } finally {
      _running = false;
      _idle?.complete();
      if (!_disposed) notifyListeners();
      if (_pendingReplan && !_disposed) {
        _pendingReplan = false;
        unawaited(refresh());
      }
    }
  }

  Future<void> configure(Map<String, dynamic> changes) async {
    if (changes.containsKey('primaryDevice') && onPrimaryRequest != null) {
      await onPrimaryRequest!(changes['primaryDevice'] == true);
      changes = {...changes}..remove('primaryDevice');
      if (changes.isEmpty) return;
    }
    final latest = await engine.preferences();
    final value = NotificationPreferences.fromJson({
      ...latest.toJson(),
      ...changes,
    });
    await engine.configure(value);
    // A running poll may coalesce refresh(), so publish the persisted user
    // choice now rather than leaving a confirmed switch visually stale.
    preferences = value;
    if (!_disposed) notifyListeners();
    await refresh();
  }

  Future<void> applyPrimary(bool value) async {
    final latest = await engine.preferences();
    final next = NotificationPreferences.fromJson({
      ...latest.toJson(),
      'primaryDevice': value,
    });
    if (latest.primaryDevice != value) await engine.configure(next);
    preferences = next;
    if (!_disposed) notifyListeners();
    await refresh();
  }

  Future<void> stop() async {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_running) await _idle?.future;
  }

  Future<void> resume(String zone) async {
    _disposed = false;
    await start(zone);
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
    diagnostics.record(NotificationDiagnosticCode.testRequested);
    granted = await engine.scheduler.granted();
    final platform = engine.scheduler is PlatformNotificationScheduler
        ? engine.scheduler as PlatformNotificationScheduler
        : null;
    // An explicit Windows diagnostic request can attempt the OS API when
    // querying its setting is unavailable. A known denial still blocks it.
    final diagnosticAttempt =
        Platform.isWindows &&
        platform?.ready == true &&
        platform?.permissionStatus == 'unknown';
    if (!granted && !diagnosticAttempt) {
      if (engine.scheduler is PlatformNotificationScheduler &&
          (engine.scheduler as PlatformNotificationScheduler)
                  .permissionStatus ==
              'unknown') {
        throw const domain.ValidationException(
          'Chưa xác minh được kênh thông báo. Mở cài đặt hệ thống và thử lại; có thể xuất chẩn đoán nếu bạn bật đồng ý.',
        );
      }
      throw const domain.ValidationException(
        'Hãy cho phép thông báo trong cài đặt trước.',
      );
    }
    await engine.scheduler.show(
      id: 2147483646,
      title: 'Thử thông báo DayMind',
      body: 'Thông báo thử im lặng do bạn yêu cầu.',
    );
    if (diagnosticAttempt) {
      granted = await engine.scheduler
          .granted(); // Never infer permission/banner from show success.
      if (!_disposed) notifyListeners();
    }
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
      (engine.scheduler as PlatformNotificationScheduler).onForegroundCue =
          null;
      (engine.scheduler as PlatformNotificationScheduler).onOpen = null;
    }
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
