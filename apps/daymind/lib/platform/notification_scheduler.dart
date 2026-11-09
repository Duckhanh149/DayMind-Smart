import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../features/reminders/domain/reminder.dart';

class PlatformNotificationScheduler implements NotificationScheduler {
  static const channel = MethodChannel('daymind/reminders');
  final plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  void Function()? onChanged;
  void Function(String)? onInApp;
  @override
  bool get supportsClosedApp => Platform.isAndroid;
  Future<String> initialize(String databasePath) async {
    tzdata.initializeTimeZones();
    var timezone = 'UTC';
    try {
      timezone = (await FlutterTimezone.getLocalTimezone()).identifier;
      timeLocation(timezone);
    } catch (_) {
      timezone = 'UTC';
      // With an unknown local zone, keep reminders disabled until a valid zone is selected.
      return '';
    }
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('initialize', {'path': databasePath});
      channel.setMethodCallHandler((call) async {
        if (call.method == 'changed') {
          if (call.arguments is String) onInApp?.call(call.arguments as String);
          onChanged?.call();
        }
      });
      _ready = true;
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
              onDidReceiveNotificationResponse: (_) => onChanged?.call(),
            ) ??
            false;
      } catch (_) {
        _ready = false;
      }
    }
    return timezone;
  }

  @override
  Future<bool> granted() async {
    if (!_ready) return false;
    if (Platform.isAndroid) {
      return await channel.invokeMethod<bool>('granted') ?? false;
    }
    return Platform.isWindows;
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return await channel.invokeMethod<bool>('requestPermission') ?? false;
    }
    return granted();
  }

  Future<void> openSettings() async {
    if (Platform.isAndroid) await channel.invokeMethod<void>('openSettings');
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
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('test', {'title': title, 'body': body});
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
  }
}
