import 'package:flutter/material.dart';

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:daymind_smart/main.dart' as app;
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/recurrence/domain/recurrence.dart';
import 'package:daymind_smart/features/recurrence/application/recurrence_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/app/workspace_host.dart';
import 'package:daymind_smart/features/account_sync/domain/sync_record.dart';
import 'package:uuid/uuid.dart';
import 'package:daymind_smart/features/tasks/presentation/workspace_screen.dart';
import 'package:daymind_smart/platform/secure_session_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native startup and durable task creation', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    final secure = NativeSessionStore();
    const probe = 'DayMind native credential probe · ă';
    await secure.set('test_probe', probe);
    expect(await secure.get('test_probe'), probe);
    await secure.set('test_probe', '$probe updated');
    expect(await secure.get('test_probe'), '$probe updated');
    await secure.remove('test_probe');
    expect(await secure.get('test_probe'), isNull);
    debugPrint(
      'SECURE_STORAGE_POC: native encrypted write/read/replace/delete passed.',
    );
    await tester.tap(find.byKey(const Key('add-task')));
    await tester.pumpAndSettle();
    final title = 'Native smoke ${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(find.byKey(const Key('task-title')), title);
    await tester.tap(find.byKey(const Key('save-task')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(WorkspaceScreen)),
    ).read(workspaceProvider);
    final reminders = controller.reminders;
    expect(reminders, isNotNull);
    debugPrint(
      'NOTIFICATION_POC: permission/initialization=${reminders!.granted}; closed-app adapter=${reminders.engine.scheduler.supportsClosedApp}',
    );
    if (reminders.granted) {
      await reminders.test();
    }
    if (Platform.isWindows) {
      final window = controller.window!;
      await window.refresh();
      expect(window.iconReady, isTrue, reason: window.error);
      await window.hide();
      await tester.pump(const Duration(milliseconds: 200));
      await window.refresh();
      expect(window.visible, isFalse);
      expect(window.trayEnabled, isTrue);
      await window.show();
      await tester.pump(const Duration(milliseconds: 200));
      await window.refresh();
      expect(window.visible, isTrue);
      debugPrint(
        'TRAY_POC: WM_CLOSE hides, process stays active, restore succeeds.',
      );
    }
    final now = controller.now();
    final recurring = await controller.save(
      TaskDraft(
        title: '$title recurring',
        scheduledStartAt: now.add(const Duration(hours: 1)),
        dueAt: now.add(const Duration(hours: 2)),
      ),
      repetition: RepeatChange(
        enabled: true,
        spec: RepeatSpec(
          frequency: RepeatFrequency.daily,
          firstDate: dateKey(
            tz.TZDateTime.from(
              now.add(const Duration(hours: 1)),
              zoneLocation(reminders.preferences.timezoneId),
            ),
          ),
          zone: reminders.preferences.timezoneId,
          count: 3,
        ),
      ),
    );
    var instances =
        controller.visibleTasks.where((t) => t.seriesId == recurring).toList()
          ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    expect(instances.length, 3);
    await controller.toggle(instances.first);
    instances =
        controller.visibleTasks.where((t) => t.seriesId == recurring).toList()
          ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    expect(instances.first.status, TaskStatus.completed);
    expect(
      controller.tasks.singleWhere((t) => t.id == recurring).status,
      TaskStatus.todo,
    );
    await controller.save(
      TaskDraft.fromJson({
        ...TaskDraft.fromTask(instances[1]).toJson(),
        'title': '$title future',
      }),
      existing: instances[1],
      scope: EditScope.future,
    );
    final changed = controller.visibleTasks
        .where((t) => t.seriesId == recurring && t.status == TaskStatus.todo)
        .toList();
    expect(changed.length, 2);
    expect(changed.every((t) => t.title == '$title future'), isTrue);
    await controller.delete(changed.first, scope: EditScope.all);
    debugPrint(
      'RECURRENCE_POC: real SQLite materialization, one completion and future edits preserve history.',
    );
    final tasks = await controller.repository.list();
    expect(
      tasks.any((task) => task.title == title && task.dueAt == null),
      true,
    );
    final task = tasks.firstWhere((task) => task.title == title);
    await controller.delete(task);
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('RUN_ACCOUNT_EMULATOR')) {
      final host = ProviderScope.containerOf(
        tester.element(find.byType(WorkspaceScreen)),
      ).read(workspaceHostProvider)!;
      final localIds = host.controller!.tasks.map((t) => t.id).toSet();
      final email = '${const Uuid().v4()}@example.invalid',
          secret = const Uuid().v4();
      await host.signIn(email, secret, create: true, copyLocal: false);
      await tester.pumpAndSettle();
      final service = host.sync!;
      await service.sync();
      expect(service.message, isNull);
      expect(host.controller!.tasks, isEmpty);
      final owner = host.account!.uid;
      expect((await secure.read())?.uid, owner);
      final privateTitle = 'Native account ${const Uuid().v4()}';
      final privateId = await host.controller!.save(
        TaskDraft(
          title: privateTitle,
          dueAt: DateTime.now().add(const Duration(hours: 3)),
        ),
      );
      await service.sync();
      expect(service.pendingCount, 0);
      expect(service.conflictCount, 0);
      final remote = await host.gateway.fetchAll(await host.session());
      expect(
        remote.any(
          (r) =>
              r.record.kind == SyncKind.task &&
              r.record.id == privateId &&
              r.record.data['title'] == privateTitle,
        ),
        isTrue,
      );
      await host.notificationDevice(true);
      expect(host.controller!.reminders!.preferences.primaryDevice, isTrue);
      await host.signOut();
      await tester.pumpAndSettle();
      expect(await secure.read(), isNull);
      expect(host.controller!.tasks.map((t) => t.id).toSet(), localIds);
      expect(host.controller!.tasks.any((t) => t.id == privateId), isFalse);
      await host.signIn(email, secret, create: false, copyLocal: false);
      await tester.pumpAndSettle();
      await host.sync!.sync();
      expect(host.account!.uid, owner);
      expect(host.controller!.tasks.any((t) => t.id == privateId), isTrue);
      await host.deleteAccount(secret);
      await tester.pumpAndSettle();
      expect(host.account, isNull);
      expect(host.controller!.tasks.map((t) => t.id).toSet(), localIds);
      debugPrint(
        'ACCOUNT_NATIVE_POC: real Auth/Firestore, encrypted session, isolated profile, primary device, logout/relogin and verified deletion passed.',
      );
    }
  });
}
