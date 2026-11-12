import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/features/reminders/application/reminder_coordinator.dart';
import 'package:daymind_smart/features/reminders/application/reminder_engine.dart';
import 'package:daymind_smart/features/reminders/domain/reminder.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';

import 'reminder_engine_test.dart' show FakeScheduler;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final action in ['primary', 'persistedPrimary', 'quiet']) {
    test(
      'confirmed $action setting is visible while a background poll is active',
      () async {
        final db = DaymindDatabase(NativeDatabase.memory());
        final engine = ReminderEngine(db, FakeScheduler());
        await engine.configure(
          const NotificationPreferences(primaryDevice: false),
        );
        final entered = Completer<void>(), release = Completer<void>();
        var holding = false;
        final coordinator = ReminderCoordinator(engine, () async {
          if (holding) {
            if (!entered.isCompleted) entered.complete();
            await release.future;
          }
          return [];
        });
        await coordinator.refresh();
        holding = true;
        final poll = coordinator.refresh();
        await entered.future;
        try {
          if (action == 'quiet') {
            await coordinator.configure({'quietEnabled': false});
            expect(coordinator.preferences.quietEnabled, isFalse);
            expect((await engine.preferences()).quietEnabled, isFalse);
          } else {
            if (action == 'persistedPrimary') {
              await engine.configure(
                const NotificationPreferences(primaryDevice: true),
              );
            }
            await coordinator.applyPrimary(true);
            expect(coordinator.preferences.primaryDevice, isTrue);
            expect((await engine.preferences()).primaryDevice, isTrue);
          }
        } finally {
          holding = false;
          release.complete();
          await poll;
          await coordinator.stop();
          coordinator.dispose();
          await db.close();
        }
      },
    );
  }
}
