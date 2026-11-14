import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/features/reminders/domain/notification_diagnostics.dart';
import 'package:daymind_smart/platform/window_lifecycle.dart';

void main() {
  test(
    'trace requires consent, is bounded, enum-only and clears on withdrawal',
    () {
      final d = NotificationDiagnostics();
      d.record(NotificationDiagnosticCode.osFailed);
      expect(d.export(), isEmpty);
      d.enabled = true;
      for (var i = 0; i < 160; i++) {
        d.record(
          NotificationDiagnosticCode.osAccepted,
          setting: 1000,
          state: -1,
        );
      }
      expect(d.export(), hasLength(128));
      expect(
        d.export().every(
          (e) => e.keys.toSet().difference({'elapsedMs', 'code'}).isEmpty,
        ),
        isTrue,
      );
      d.export().first['private'] = 'sentinel';
      expect(d.export().toString(), isNot(contains('sentinel')));
      d.enabled = false;
      expect(d.export(), isEmpty);
      d.enabled = true;
      expect(d.export(), isEmpty);
    },
  );
  test(
    'close limitation follows actual tray readiness, not preference alone',
    () {
      final window = WindowLifecycle();
      window.trayEnabled = true;
      expect(window.keepsRunningOnClose, isFalse);
      expect(window.notificationLifetime, contains('dừng nhắc'));
      window.iconReady = true;
      expect(window.keepsRunningOnClose, isTrue);
      expect(window.notificationLifetime, contains('tiếp tục nhắc'));
      window.trayEnabled = false;
      expect(window.keepsRunningOnClose, isFalse);
    },
  );
}
