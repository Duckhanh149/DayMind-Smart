import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WindowLifecycle extends ChangeNotifier {
  static const channel = MethodChannel('daymind/window');
  bool visible = true, iconReady = false, trayEnabled = false;
  String? error;
  int? notificationSetting, notificationState;
  bool get keepsRunningOnClose => trayEnabled && iconReady;
  String get notificationLifetime => keepsRunningOnClose
      ? 'Đóng cửa sổ (X): DayMind thu vào khay và tiếp tục nhắc khi máy đang chạy.'
      : 'Khay hệ thống đang tắt hoặc chưa sẵn sàng: đóng cửa sổ sẽ thoát và dừng nhắc.';
  Future<void> openNotificationSettings() =>
      channel.invokeMethod<void>('openNotificationSettings');
  void Function(bool)? onVisibility;
  void _state(Map<dynamic, dynamic>? value) {
    if (value == null) return;
    notificationSetting =
        value['notificationSetting'] is int &&
            (value['notificationSetting'] as int) >= 0 &&
            (value['notificationSetting'] as int) <= 4
        ? value['notificationSetting'] as int
        : null;
    notificationState =
        value['notificationState'] is int &&
            (value['notificationState'] as int) >= 1 &&
            (value['notificationState'] as int) <= 7
        ? value['notificationState'] as int
        : null;
    visible = value['visible'] == true;
    iconReady = value['iconReady'] == true;
    trayEnabled = value['trayEnabled'] == true;
    onVisibility?.call(visible);
    notifyListeners();
  }

  Future<void> start(bool enabled) async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'visibility') {
        visible = call.arguments == true;
        onVisibility?.call(visible);
        notifyListeners();
      }
    });
    await configure(enabled);
  }

  Future<void> configure(bool enabled) async {
    try {
      _state(
        await channel.invokeMapMethod<dynamic, dynamic>('configure', enabled),
      );
      error = enabled && !iconReady
          ? 'Khay hệ thống chưa sẵn sàng. DayMind giữ cửa sổ truy cập được; đóng cửa sổ sẽ thoát.'
          : null;
    } catch (e) {
      error = 'Chưa thiết lập được khay hệ thống: $e';
    }
    notifyListeners();
  }

  Future<void> refresh() async =>
      _state(await channel.invokeMapMethod<dynamic, dynamic>('state'));
  Future<void> hide() async =>
      _state(await channel.invokeMapMethod<dynamic, dynamic>('hide'));
  Future<void> show() async =>
      _state(await channel.invokeMapMethod<dynamic, dynamic>('show'));
  Future<void> quit() async => channel.invokeMethod<void>('quit');
  @override
  void dispose() {
    channel.setMethodCallHandler(null);
    super.dispose();
  }
}
