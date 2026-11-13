import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/reminders/application/reminder_coordinator.dart';
import 'package:daymind_smart/features/reminders/application/reminder_engine.dart';
import 'package:daymind_smart/features/reminders/presentation/notification_pages.dart';
import 'package:daymind_smart/platform/window_lifecycle.dart';

import 'reminder_engine_test.dart' show FakeScheduler;

void main() {
  testWidgets(
    'Windows settings explain actual close/exit/reboot limits and offer OS settings',
    (tester) async {
      final db = DaymindDatabase(NativeDatabase.memory());
      final coordinator = ReminderCoordinator(
        ReminderEngine(db, FakeScheduler()),
        () => Future.value([]),
      );
      final window = WindowLifecycle();
      var opened = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(WindowLifecycle.channel, (call) async {
            if (call.method == 'openNotificationSettings') {
              opened++;
              return null;
            }
            return {
              'visible': true,
              'trayEnabled': true,
              'iconReady': false,
              'notificationSetting': 2,
              'notificationState': 6,
            };
          });
      await window.start(true);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        coordinator.dispose();
        window.dispose();
        await db.close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(WindowLifecycle.channel, null);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationSettingsSection(
                reminders: coordinator,
                window: window,
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('đóng cửa sổ sẽ thoát'), findsOneWidget);
      expect(
        find.textContaining('khởi động lại: không có nhắc nền'),
        findsOneWidget,
      );
      expect(find.textContaining('đang bị chặn'), findsOneWidget);
      final button = find.text('Mở cài đặt thông báo Windows');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
