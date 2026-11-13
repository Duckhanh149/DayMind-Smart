import 'dart:io';

import '../features/reminders/domain/notification_diagnostics.dart';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../features/reminders/domain/reminder.dart';
import '../features/companion/domain/companion.dart';

class PlatformNotificationScheduler implements NotificationScheduler {
  PlatformNotificationScheduler({NotificationDiagnostics? diagnostics})
    : diagnostics = diagnostics ?? NotificationDiagnostics();
  final NotificationDiagnostics diagnostics;
  static const windowChannel = MethodChannel('daymind/window');
  String permissionStatus = 'unknown';
  int? osSetting, osState;
  bool get ready => _ready;
  static const channel = MethodChannel('daymind/reminders');
  final plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? initializationError;
  void Function()? onChanged;
  void Function(String)? onInApp;
  void Function(CompanionCue)? onForegroundCue;
  static CompanionCue? foregroundCue(Object? data) {
    final String? title = data is String
        ? data
        : data is Map && data['title'] is String
        ? data['title'] as String
        : null;
    if (title == null || title.isEmpty || title.length > 1024) return null;
    final digest = data is Map && data['kind'] == 'digest';
    return digest
        ? CompanionCue(CompanionEvent.dailyDigest, title, summary: title)
        : CompanionCue(
            CompanionEvent.reminderDue,
            'Đến giờ: $title',
            task: title,
          );
  }

  void Function()? onOpen;
  Future<String> localTimezone() async {
    final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    return timeLocation(zone).name;
  }

  @override
  bool get supportsClosedApp => Platform.isAndroid;
  Future<String> initialize(String databasePath) async {
    _ready = false;
    initializationError = null;
    permissionStatus = 'unknown';
    osSetting = null;
    osState = null;
    tzdata.initializeTimeZones();
    var timezone = 'UTC';
    try {
      timezone = await localTimezone();
    } catch (_) {
      timezone = 'UTC';
      initializationError = 'Chưa xác định được múi giờ thiết bị. Kiểm tra múi giờ hệ thống và mở lại ứng dụng.';
      // With an unknown local zone, keep reminders disabled until a valid zone is selected.
      diagnostics.record(NotificationDiagnosticCode.timezoneUnavailable);
      return '';
    }
    if (Platform.isAndroid) {
      try {
        await channel.invokeMethod<void>('initialize', {'path': databasePath});
        channel.setMethodCallHandler((call) async {
          if (call.method == 'openNotifications') onOpen?.call();
          if (call.method == 'changed') {
            final cue = foregroundCue(call.arguments);
            if (cue != null) {
              if (onForegroundCue != null) {
                onForegroundCue!(cue);
              } else {
                onInApp?.call(cue.task ?? cue.summary!);
              }
            }
            onChanged?.call();
          }
        });
        _ready = true;
        if (await channel.invokeMethod<bool>('consumeOpen') ?? false) {
          onOpen?.call();
        }
      } catch (_) {
        initializationError = 'Chưa khởi tạo được thông báo Android. Kiểm tra quyền và mở lại ứng dụng.';
      }
    } else if (Platform.isWindows) {
      try {
        _ready =
            await plugin.initialize(
              settings: const InitializationSettings(
                windows: WindowsInitializationSettings(
                  appName: 'DayMind SMART',
                  appUserModelId: 'dev.daymind.DayMindSMART',
                  guid: '58f1b340-572b-49db-8b03-3712d9ff2dde',
                ),
              ),
              onDidReceiveNotificationResponse: (_) {
                onChanged?.call();
                onOpen?.call();
              },
            ) ??
            false;
        if (_ready &&
            (await plugin.getNotificationAppLaunchDetails())
                    ?.didNotificationLaunchApp ==
                true) {
          onOpen?.call();
        }
        if (!_ready) {
          initializationError =
              'Hệ điều hành chưa khởi tạo được kênh thông báo.';
        }
      } catch (_) {
        _ready = false;
        initializationError = 'Chưa khởi tạo được thông báo Windows. Kiểm tra cài đặt thông báo và mở lại ứng dụng.';
      }
    }
    diagnostics.record(
      _ready
          ? NotificationDiagnosticCode.initialized
          : NotificationDiagnosticCode.initializationFailed,
    );
    return timezone;
  }

  @override
  Future<bool> granted() async {
    if (!_ready) return false;
    if (Platform.isAndroid) {
      final allowed = await channel.invokeMethod<bool>('granted') ?? false;
      permissionStatus = allowed ? 'granted' : 'denied';
      diagnostics.record(
        allowed
            ? NotificationDiagnosticCode.permissionGranted
            : NotificationDiagnosticCode.permissionDenied,
      );
      return allowed;
    }
    if (Platform.isWindows) {
      try {
        final state = await windowChannel.invokeMapMethod<String, dynamic>(
          'state',
        );
        final setting = state?['notificationSetting'],
            focus = state?['notificationState'];
        osSetting = setting is int && setting >= 0 && setting <= 4
            ? setting
            : null;
        osState = focus is int && focus >= 1 && focus <= 7 ? focus : null;
        permissionStatus = osSetting == null
            ? 'unknown'
            : osSetting == 0
            ? 'granted'
            : 'denied';
      } catch (_) {
        permissionStatus = 'unknown';
        osSetting = null;
        osState = null;
      }
      diagnostics.record(
        permissionStatus == 'granted'
            ? NotificationDiagnosticCode.permissionGranted
            : permissionStatus == 'denied'
            ? NotificationDiagnosticCode.permissionDenied
            : NotificationDiagnosticCode.permissionUnknown,
        setting: osSetting,
        state: osState,
      );
      return permissionStatus == 'granted';
    }
    return false;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) {
      throw StateError(initializationError ?? 'Thông báo chưa sẵn sàng.');
    }
    if (Platform.isAndroid) {
      return await channel.invokeMethod<bool>('requestPermission') ?? false;
    }
    return granted();
  }

  Future<void> openSettings() async {
    if (Platform.isAndroid) await channel.invokeMethod<void>('openSettings');
    if (Platform.isWindows) {
      await windowChannel.invokeMethod<void>('openNotificationSettings');
    }
  }

  Future<void> deactivate() async {
    onChanged = null;
    onInApp = null;
    onForegroundCue = null;
    onOpen = null;
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('deactivate');
      channel.setMethodCallHandler(null);
    } else if (Platform.isWindows && _ready) {
      await plugin.cancelAll();
    }
    _ready = false;
  }

  @override
  Future<void> schedule({
    required int id,
    required String eventKey,
    required DateTime at,
  }) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('schedule', {
        'id': id,
        'eventKey': eventKey,
        'at': at.millisecondsSinceEpoch,
      });
    }
    // Windows uses the guarded live engine; closed-process delivery is explicitly unavailable until its packaging POC passes.
  }

  @override
  Future<void> cancel(int id) async {
    if (Platform.isAndroid && _ready) {
      await channel.invokeMethod<void>('cancel', {'id': id});
    }
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? eventKey,
  }) async {
    diagnostics.record(NotificationDiagnosticCode.osAttempt);
    try {
      if (!_ready) throw StateError('Thông báo chưa sẵn sàng.');
      if (Platform.isAndroid) {
        await channel.invokeMethod<void>('test', {
          'title': title,
          'body': body,
        });
      } else if (Platform.isWindows && _ready) {
        await plugin.show(
          id: id,
          title: title,
          body: body,
          payload: eventKey,
          notificationDetails: NotificationDetails(
            windows: WindowsNotificationDetails(
              audio: WindowsNotificationAudio.silent(),
            ),
          ),
        );
      }
      diagnostics.record(NotificationDiagnosticCode.osAccepted);
    } catch (_) {
      diagnostics.record(NotificationDiagnosticCode.osFailed);
      rethrow;
    }
  }
}
