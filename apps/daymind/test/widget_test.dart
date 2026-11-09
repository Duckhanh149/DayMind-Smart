import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/app/app.dart';
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/companion/presentation/companion_card.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:daymind_smart/features/reminders/application/reminder_engine.dart';
import 'package:daymind_smart/features/reminders/application/reminder_coordinator.dart';
import 'package:daymind_smart/features/reminders/presentation/notification_pages.dart';
import 'package:daymind_smart/features/reminders/presentation/reminder_editor.dart';

import 'reminder_engine_test.dart' show FakeScheduler;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    tzdata.initializeTimeZones();
    final loader = FontLoader('BeVietnamPro');
    for (final weight in [400, 500, 600, 700]) {
      loader.addFont(
        rootBundle.load('assets/fonts/be-vietnam-pro-$weight.ttf'),
      );
    }
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<(DaymindDatabase, WorkspaceController)> mount(
    WidgetTester tester,
    Size size, {
    bool seed = false,
    double scale = 1,
    bool notifications = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    final now = DateTime.utc(2026, 11, 8, 3);
    final db = DaymindDatabase(NativeDatabase.memory());
    final repo = SqliteTaskRepository(db, clock: () => now);
    if (seed) {
      await repo.save(
        TaskDraft(
          title: 'Hoàn thiện kế hoạch tuần mới',
          description: 'Chọn ba điều quan trọng nhất cho tuần này.',
          priority: TaskPriority.high,
          categoryId: 'work',
          dueAt: now.add(const Duration(hours: 7)),
        ),
      );
      await repo.save(
        TaskDraft(
          title: 'Dành 20 phút đọc sách',
          categoryId: 'learning',
          dueAt: now.add(const Duration(hours: 12)),
        ),
      );
      await repo.save(
        TaskDraft(
          title: 'Đi bộ và thở chậm một chút',
          categoryId: 'personal',
          dueAt: now.add(const Duration(hours: 10)),
        ),
      );
    }
    final temp = Directory.systemTemp.createTempSync('daymind-widget-');
    final controller = WorkspaceController(
      repo,
      StaticAssetImporter(temp),
      clock: () => now,
    );
    await controller.load();
    if (notifications) {
      final coordinator = ReminderCoordinator(
        ReminderEngine(db, FakeScheduler(), clock: () => now),
        repo.list,
      );
      controller.attachReminders(coordinator);
      await coordinator.refresh();
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workspaceProvider.overrideWith((ref) => controller)],
        child: const DaymindApp(),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      temp.deleteSync(recursive: true);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    return (db, controller);
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'notification center and advanced reminder form at text scale $scale',
      (tester) async {
        final (_, controller) = await mount(
          tester,
          const Size(360, 800),
          scale: scale,
          notifications: true,
        );
        controller.openNotifications();
        await tester.pumpAndSettle();
        expect(find.byType(NotificationCenterPage), findsOneWidget);
        if (const bool.fromEnvironment('GENERATE_GOLDENS') && scale == 1) {
          await expectLater(
            find.byType(DaymindApp),
            matchesGoldenFile('previews/notifications.png'),
          );
        }
        await tester.scrollUntilVisible(
          find.text('Hiện một thông báo thử im lặng'),
          250,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Công việc').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('add-task')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chi tiết & lên lịch'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(ReminderEditor),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (name, size, scale) in [
    ('phone', const Size(390, 844), 1.0),
    ('desktop', const Size(1440, 960), 1.0),
    ('phone-large-text', const Size(360, 800), 2.0),
    ('tablet', const Size(768, 1024), 1.0),
  ]) {
    testWidgets('responsive $name renders without layout exceptions', (
      tester,
    ) async {
      await mount(tester, size, seed: true, scale: scale);
      expect(find.text('Một ngày có chủ đích.'), findsOneWidget);
      if (scale > 1) {
        await tester.scrollUntilVisible(find.byType(CompanionCard), 250);
      }
      expect(find.byType(CompanionCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('GENERATE_GOLDENS') &&
          scale == 1 &&
          name != 'tablet') {
        await expectLater(
          find.byType(DaymindApp),
          matchesGoldenFile('previews/$name.png'),
        );
      }
    });
  }
  testWidgets(
    'mobile creates task without deadline, completes and restores it',
    (tester) async {
      final (_, controller) = await mount(tester, const Size(390, 844));
      await tester.tap(find.byKey(const Key('add-task')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('task-title')),
        'Gọi điện cho mẹ',
      );
      await tester.tap(find.byKey(const Key('save-task')));
      await tester.pumpAndSettle();
      expect(controller.tasks.single.title, 'Gọi điện cho mẹ');
      expect(controller.tasks.single.dueAt, isNull);
      await tester.tap(find.text('Công việc').last);
      await tester.pumpAndSettle();
      expect(find.text('Gọi điện cho mẹ'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(controller.tasks.single.status, TaskStatus.completed);
      await controller.delete(controller.tasks.single);
      await tester.pumpAndSettle();
      expect(controller.tasks.single.deletedAt, isNotNull);
      await controller.restore(controller.tasks.single);
      await tester.pumpAndSettle();
      expect(controller.tasks.single.deletedAt, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('invalid task title keeps form open and draft editable', (
    tester,
  ) async {
    await mount(tester, const Size(390, 844));
    await tester.tap(find.byKey(const Key('add-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-task')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('form-error')), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('task-title')),
      'Bản nháp vẫn ở đây',
    );
    expect(find.text('Bản nháp vẫn ở đây'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'keyboard in editor leaves save accessible and companion outside the form',
    (tester) async {
      await mount(tester, const Size(390, 844));
      await tester.tap(find.byKey(const Key('add-task')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(CompanionCard),
        ),
        findsNothing,
      );
      expect(find.byKey(const Key('save-task')).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    },
  );
  testWidgets('companion page displays mascot and settings on phone', (
    tester,
  ) async {
    await mount(tester, const Size(390, 844));
    await tester.tap(find.text('Companion').last);
    await tester.pumpAndSettle();
    expect(find.text('Một người bạn nhỏ.'), findsOneWidget);
    expect(find.byType(MamMascot), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('GENERATE_GOLDENS')) {
      await expectLater(
        find.byType(DaymindApp),
        matchesGoldenFile('previews/companion.png'),
      );
    }
  });
}
