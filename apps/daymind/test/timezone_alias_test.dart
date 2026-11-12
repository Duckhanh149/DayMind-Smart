import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:daymind_smart/platform/notification_scheduler.dart';
import 'package:timezone/data/latest.dart' as reduced;
import 'package:timezone/data/latest_all.dart' as complete;
import 'package:timezone/timezone.dart' as tz;
import 'package:daymind_smart/features/reminders/domain/reminder.dart';
import 'package:daymind_smart/features/recurrence/domain/recurrence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native Windows timezone response canonicalizes before scheduler initialization', () async {
    reduced.initializeTimeZones();
    const channel = MethodChannel('flutter_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => 'Asia/Saigon');
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    expect(
      await PlatformNotificationScheduler().localTimezone(),
      'Asia/Ho_Chi_Minh',
    );
  });
  test(
    'Windows Asia/Saigon alias works for reminders and persisted recurrence',
    () {
      reduced.initializeTimeZones();
      expect(
        () => tz.getLocation('Asia/Saigon'),
        throwsA(isA<tz.LocationNotFoundException>()),
      );
      for (final location in [
        timeLocation('Asia/Saigon'),
        zoneLocation('Asia/Saigon'),
      ]) {
        final local = tz.TZDateTime(location, 2026, 11, 12, 9);
        expect(local.toUtc(), DateTime.utc(2026, 11, 12, 2));
        expect(location.name, 'Asia/Ho_Chi_Minh');
      }
      complete.initializeTimeZones();
      expect(tz.getLocation('Asia/Saigon').name, 'Asia/Saigon');
      expect(() => timeLocation('Invalid/Timezone'), throwsA(anything));
    },
  );
}
