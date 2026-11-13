import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/platform/notification_scheduler.dart';
import 'package:daymind_smart/features/reminders/domain/reminder.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';

Future<void> windowsNotificationProbe(
  WidgetTester tester,
  WorkspaceController c,
) async {
  if (!Platform.isWindows) return;
  final service = c.reminders!,
      scheduler =
          c.reminders!.engine.scheduler as PlatformNotificationScheduler;
  final window = c.window!, saved = service.preferences.toJson();
  expect(scheduler.supportsClosedApp, isFalse);
  expect(
    await scheduler.granted(),
    isTrue,
    reason: 'CI must report real enabled Windows ToastNotifier settings.',
  );
  final title = 'Synthetic tray probe ${const Uuid().v4()}';
  final traceEnabled = scheduler.diagnostics.enabled;
  String? taskId;
  try {
    await service.configure({'primaryDevice': true, 'quietEnabled': false});
    taskId = await c.save(
      TaskDraft(
        title: title,
        dueAt: DateTime.now().add(const Duration(hours: 1)),
      ),
      notifications: TaskReminderConfig('custom', [
        ReminderRule(
          id: 'tray-probe',
          taskId: '',
          kind: ReminderKind.absolute,
          absoluteAt: DateTime.now().add(const Duration(seconds: 5)),
        ),
      ]),
    );
    await window.hide();
    await window.refresh();
    expect(window.visible, isFalse);
    scheduler.diagnostics.enabled = false;
    scheduler.diagnostics.enabled = true; // Synthetic integration-only trace.
    await tester.pump(const Duration(seconds: 6));
    final deadline = Stopwatch()..start();
    var state = '';
    var found = false;
    while (deadline.elapsed < const Duration(seconds: 15)) {
      await service.refresh();
      final events = await service.engine.events();
      state = events.where((e) => e.taskId == taskId).firstOrNull?.state ?? '';
      final active = await scheduler.plugin.getActiveNotifications();
      found = active.any(
        (n) => n.title == title || (n.body?.contains(title) ?? false),
      );
      if (state == 'unknown' && (found || scheduler.osState != 5)) break;
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(
      state,
      'unknown',
      reason: 'The real reminder must be claimed and routed to OS while the main window is hidden.',
    );
    expect(service.error, isNull);
    final accepted = scheduler.diagnostics.export().any(
      (e) => e['code'] == 'osAccepted',
    );
    expect(
      accepted,
      isTrue,
      reason: 'The actual OS show API must return successfully while hidden.',
    );
    if (scheduler.osState == 5) {
      expect(
        found,
        isTrue,
        reason: 'When OS accepts notifications, the synthetic tray reminder must appear in OS history.',
      );
    }
    debugPrint(
      'WINDOWS_TRAY_NOTIFICATION_POC: ${jsonEncode({'windowHidden': true, 'engineClaimed': state == 'unknown', 'osApiAccepted': accepted, 'osSetting': scheduler.osSetting, 'osState': scheduler.osState, 'foundInOsHistory': found, 'bannerVisibilityConfirmed': false, 'deliveryAfterProcessExitSupported': false})}',
    );
  } finally {
    scheduler.diagnostics.enabled = traceEnabled;
    await window.show();
    await tester.pump(const Duration(milliseconds: 300));
    for (final n in await scheduler.plugin.getActiveNotifications()) {
      if ((n.title == title || (n.body?.contains(title) ?? false)) &&
          n.id != null) {
        await scheduler.plugin.cancel(id: n.id!);
      }
    }
    final task = c.tasks.where((t) => t.id == taskId).firstOrNull;
    if (task != null) await c.delete(task);
    await service.configure(saved);
  }
}
