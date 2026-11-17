import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Native transport is replaceable in tests; production always uses the OS plugin.
abstract interface class IosNotificationBackend {
  Future<bool> initialize(void Function(String, String) onResponse);
  Future<bool> granted();
  Future<bool> requestPermission();
  Future<Set<int>> pending();
  Future<void> schedule(int id, String key, DateTime at, String title);
  Future<void> show(int id, String title, String body);
  Future<void> cancel(int id);
  Future<void> cancelAll();
}

class DarwinNotificationBackend implements IosNotificationBackend {
  final plugin = FlutterLocalNotificationsPlugin();
  IOSFlutterLocalNotificationsPlugin get ios => plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >()!;
  static const details = NotificationDetails(
    iOS: DarwinNotificationDetails(
      presentAlert: false,
      presentBanner: false,
      presentList: false,
      presentBadge: false,
      presentSound: false,
      categoryIdentifier: 'daymind.reminder.v1',
      interruptionLevel: InterruptionLevel.passive,
    ),
  );
  @override
  Future<bool> initialize(void Function(String, String) onResponse) async {
    final ready =
        await plugin.initialize(
          settings: InitializationSettings(
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestSoundPermission: false,
              requestBadgePermission: false,
              requestProvisionalPermission: false,
              requestCriticalPermission: false,
              defaultPresentAlert: false,
              defaultPresentBanner: false,
              defaultPresentList: false,
              defaultPresentBadge: false,
              defaultPresentSound: false,
              notificationCategories: [
                DarwinNotificationCategory(
                  'daymind.reminder.v1',
                  actions: [
                    DarwinNotificationAction.plain(
                      'snooze10',
                      'Hoãn 10 phút',
                      options: {
                        DarwinNotificationActionOption.foreground,
                        DarwinNotificationActionOption.authenticationRequired,
                      },
                    ),
                    DarwinNotificationAction.plain(
                      'dismiss',
                      'Bỏ qua',
                      options: {
                        DarwinNotificationActionOption.foreground,
                        DarwinNotificationActionOption.authenticationRequired,
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          onDidReceiveNotificationResponse: (r) =>
              onResponse(r.payload ?? '', r.actionId ?? 'open'),
        ) ??
        false;
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final r = launch!.notificationResponse;
      onResponse(r?.payload ?? '', r?.actionId ?? 'open');
    }
    return ready;
  }

  @override
  Future<bool> granted() async {
    final state = await ios.checkPermissions();
    return state != null && state.isEnabled && state.isAlertEnabled;
  }

  @override
  Future<bool> requestPermission() async =>
      await ios.requestPermissions(
        alert: true,
        sound: false,
        badge: false,
        provisional: false,
        critical: false,
      ) ??
      false;
  @override
  Future<Set<int>> pending() async =>
      (await plugin.pendingNotificationRequests()).map((x) => x.id).toSet();
  @override
  Future<void> schedule(int id, String key, DateTime at, String title) =>
      plugin.zonedSchedule(
        id: id,
        title: 'DayMind · Nhắc việc',
        body: title,
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: details,
        payload: key,
      );
  @override
  Future<void> show(int id, String title, String body) => plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: details,
  );
  @override
  Future<void> cancel(int id) => plugin.cancel(id: id);
  @override
  Future<void> cancelAll() => plugin.cancelAll();
}

class IosNotificationAdapter {
  IosNotificationAdapter({
    IosNotificationBackend? backend,
    DateTime Function()? clock,
  }) : backend = backend ?? DarwinNotificationBackend(),
       clock = clock ?? DateTime.now;
  final IosNotificationBackend backend;
  final DateTime Function() clock;
  static const limit = 60;
  static const channel = MethodChannel('daymind/ios-reminders');
  bool ready = false, handedOff = false, _active = false;
  Future<String?> Function(String)? resolveTitle;
  Future<void> Function(String, String)? onEvent;
  final _buffer = <(String, String)>[];
  Future<void> _serial = Future.value();
  void receive(String key, String action) {
    if (!_active) return;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(key) ||
        !['', 'open', 'foreground', 'snooze10', 'dismiss'].contains(action)) {
      return;
    }
    if (onEvent == null) {
      if (_buffer.length < limit) _buffer.add((key, action));
      return;
    }
    _serial = _serial
        .then((_) => onEvent?.call(key, action))
        .catchError((Object _) {});
  }

  void flush() {
    final values = List.of(_buffer);
    _buffer.clear();
    for (final (key, action) in values) {
      receive(key, action);
    }
  }

  Future<void> initialize() async {
    _active = true;
    ready = await backend.initialize(receive);
    if (!ready) throw StateError('ios_init_failed');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'foreground' && call.arguments is String) {
        receive(call.arguments as String, 'foreground');
      }
    });
  }

  Future<bool> granted() async => ready && await backend.granted();
  Future<void> schedule(int id, String key, DateTime at) async {
    if (!ready || !await granted() || !at.isAfter(clock())) {
      throw StateError('ios_schedule_unavailable');
    }
    final pending = await backend.pending();
    if (!pending.contains(id) && pending.length >= limit) {
      throw StateError('ios_window_full');
    }
    final title = await resolveTitle?.call(key);
    if (title == null || title.isEmpty) throw StateError('ios_event_missing');
    await backend.schedule(id, key, at, title);
    if (!(await backend.pending()).contains(id)) {
      throw StateError('ios_handoff_unconfirmed');
    }
    handedOff = true;
  }

  Future<void> deactivate() async {
    _active = false;
    onEvent = null;
    _buffer.clear();
    await _serial;
    channel.setMethodCallHandler(null);
    if (ready) await backend.cancelAll();
    ready = false;
    handedOff = false;
  }
}
