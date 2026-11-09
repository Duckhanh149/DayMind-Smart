import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WindowLifecycle extends ChangeNotifier {
  static const channel = MethodChannel('daymind/window');
  bool visible = true, iconReady = false, trayEnabled = false;
  String? error;
  void Function(bool)? onVisibility;
  void _state(Map<dynamic, dynamic>? value) {
    if (value == null) return;
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
