import 'dart:io';
import 'dart:convert';

import '../integration_test/companion_fixtures.dart';

import 'package:go_router/go_router.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';

import 'package:daymind_smart/features/recurrence/application/recurrence_service.dart';
import 'package:daymind_smart/features/recurrence/domain/recurrence.dart';
import 'package:daymind_smart/features/calendar/presentation/calendar_page.dart';
import 'package:daymind_smart/features/assistant/presentation/assistant_pages.dart';

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

  for (final scenario in [
    (const Size(360, 800), 1.0),
    (const Size(390, 844), 2.0),
    (const Size(1440, 960), 1.0),
    (const Size(1440, 960), 2.0),
  ]) {
    testWidgets(
      'companion editor preview, validation and save at ${scenario.$1.width}px / ${scenario.$2} text',
      (tester) async {
        final (_, c) = await mount(tester, scenario.$1, scale: scenario.$2);
        await c.updateCompanionLayout(
          (v) => v.copy(placement: CompanionPlacement.right, size: 144),
        );
        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .go('/companion');
        await tester.pumpAndSettle();
        final portrait = find.byKey(const Key('companion-portrait'));
        expect(
          tester.getSize(portrait).width,
          scenario.$1.width < 600 ? (scenario.$2 == 2 ? 56 : 96) : 144,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('edit-companion-profile')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('edit-companion-profile')));
        await tester.pumpAndSettle();
        var saves = 0;
        c.onLocalChange = () => saves++;
        await tester.enterText(
          find.byKey(const Key('companion-name')),
          'Lá nhỏ',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('companion-template')));
        await tester.enterText(
          find.byKey(const Key('companion-template')),
          '{unknown}',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('preview-companion-reply')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('preview-companion-reply')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Chỉ dùng {name}'), findsOneWidget);
        expect(c.companion.name, 'Mầm');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('companion-template')));
        await tester.enterText(
          find.byKey(const Key('companion-template')),
          '{name} sẵn sàng cùng bạn.',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('preview-companion-reply')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('preview-companion-reply')));
        await tester.pumpAndSettle();
        expect(find.text('Lá nhỏ sẵn sàng cùng bạn.'), findsOneWidget);
        expect(saves, 0);
        expect(
          await c.recurrence.records.get('companion_profile', 'primary'),
          isNull,
        );
        expect(
          find.byKey(const Key('save-companion-profile')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('GENERATE_COMPANION_GOLDENS') &&
            scenario.$2 == 1) {
          await tester.ensureVisible(find.text('Lá nhỏ sẵn sàng cùng bạn.'));
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(DaymindApp),
            matchesGoldenFile(
              'previews/companion-editor-${scenario.$1.width.toInt()}.png',
            ),
          );
        }
        await tester.tap(find.byKey(const Key('save-companion-profile')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('save-companion-profile')), findsNothing);
        expect(c.companion.name, 'Lá nhỏ');
        expect(
          c.companion.messageFor(CompanionEvent.appOpen),
          'Lá nhỏ sẵn sàng cùng bạn.',
        );
        expect(saves, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a 128-image library builds a bounded visible set with large text',
    (tester) async {
      final (_, c) = await mount(tester, const Size(390, 844), scale: 2);
      await c.updateCompanionLayout((v) => v.copy(lowResource: true));
      final installed = await tester.runAsync(
        () => c.importer.installBytes(
          base64Decode(companionPngFixtures.first),
          'fixture.png',
        ),
      );
      final source = c.importer.resolve(installed)!;
      final thumbnail = (await tester.runAsync(
        () => c.importer.renderFile(installed),
      ))!;
      final names = <String>[];
      for (var i = 0; i < 127; i++) {
        final name = '${i.toRadixString(16).padLeft(64, '0')}.png';
        source.copySync('${c.importer.directory.path}/$name');
        thumbnail.copySync('${thumbnail.parent.path}/$name.png');
        names.add(name);
      }
      expect(c.importer.installed(), hasLength(128));
      // Warm only the first viewport/cache extent in the real async zone.
      await tester.runAsync(() async {
        for (final name in names.take(10)) {
          await precacheImage(
            ResizeImage(
              FileImage((await c.importer.renderFile(name))!),
              width: 64,
              height: 64,
              policy: ResizeImagePolicy.fit,
              allowUpscaling: false,
            ),
            tester.element(find.byType(Scaffold).first),
          );
        }
      });
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/companion');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('companion-library')));
      await tester.pumpAndSettle();
      expect(
        find.byType(CompanionAssetImage).evaluate().length,
        lessThanOrEqualTo(10),
      );
      expect(
        find.byKey(const Key('companion-library')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Nhân vật 128'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'calendar browsing loads the adjacent month outside the rolling horizon',
    (tester) async {
      final (_, controller) = await mount(tester, const Size(390, 844));
      await controller.save(
        TaskDraft(title: 'Chuỗi dài', dueAt: controller.now()),
        repetition: const RepeatChange(
          enabled: true,
          spec: RepeatSpec(
            frequency: RepeatFrequency.daily,
            firstDate: '2026-11-08',
            zone: 'UTC',
          ),
        ),
      );
      await tester.tap(find.text('Lịch').last);
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byTooltip('Khoảng sau'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Tháng 5 / 2027'), findsOneWidget);
      expect(
        controller.recurrence.occurrences.any((o) => o.date == '2027-06-30'),
        isFalse,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('calendar-date-2027-06-01')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-date-2027-06-01')));
      await tester.pumpAndSettle();
      expect(
        controller.recurrence.occurrences.any((o) => o.date == '2027-06-30'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('analytics uses real completion data at scale $scale', (
      tester,
    ) async {
      final (_, c) = await mount(
        tester,
        const Size(360, 800),
        seed: true,
        scale: scale,
      );
      await c.toggle(c.tasks.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thống kê').last);
      await tester.pumpAndSettle();
      expect(find.byType(AnalyticsPage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Đúng hạn khi hoàn thành'),
        150,
      );
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('GENERATE_GOLDENS') && scale == 1) {
        await tester.drag(
          find.byKey(const Key('analytics-page')),
          const Offset(0, 900),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(DaymindApp),
          matchesGoldenFile('previews/analytics.png'),
        );
      }
    });
  }
  testWidgets(
    'daily digest requires opt-in and never offers task completion actions',
    (tester) async {
      final (_, c) = await mount(
        tester,
        const Size(390, 844),
        notifications: true,
      );
      c.openNotifications();
      await tester.pumpAndSettle();
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Bản tóm tắt hằng ngày',
      );
      await tester.scrollUntilVisible(toggle, 150);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(c.reminders!.preferences.digestEnabled, isTrue);
      expect(c.reminders!.events.where((e) => e.ruleId == 'digest').length, 3);
      expect(find.text('Hoàn thành'), findsNothing);
      expect(find.text('Hoãn…'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'calendar month week day and recurrence scope at scale $scale',
      (tester) async {
        final (_, controller) = await mount(
          tester,
          const Size(360, 800),
          scale: scale,
        );
        await controller.save(
          TaskDraft(
            title: 'Việc lặp kiểm thử',
            scheduledStartAt: controller.now(),
            scheduledEndAt: controller.now().add(const Duration(hours: 1)),
            dueAt: controller.now().add(const Duration(hours: 5)),
          ),
          repetition: const RepeatChange(
            enabled: true,
            spec: RepeatSpec(
              frequency: RepeatFrequency.daily,
              firstDate: '2026-11-08',
              zone: 'UTC',
              count: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lịch').last);
        await tester.pumpAndSettle();
        expect(find.byType(CalendarPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('GENERATE_GOLDENS') && scale == 1) {
          await expectLater(
            find.byType(DaymindApp),
            matchesGoldenFile('previews/calendar.png'),
          );
        }
        await tester.tap(find.byKey(const Key('calendar-week')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('calendar-day')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Việc lặp kiểm thử').first,
          150,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Việc lặp kiểm thử').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Việc lặp kiểm thử').first);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('task-title')),
          'Chỉ sửa một lần',
        );
        await tester.tap(find.byKey(const Key('save-task')));
        await tester.pumpAndSettle();
        expect(find.text('Áp dụng thay đổi cho'), findsOneWidget);
        await tester.tap(find.text('Chỉ lần này'));
        await tester.pumpAndSettle();
        expect(
          controller.visibleTasks
              .where((t) => t.title == 'Chỉ sửa một lần')
              .length,
          1,
        );
        expect(
          controller.visibleTasks
              .where((t) => t.title == 'Việc lặp kiểm thử')
              .length,
          2,
        );
        expect(tester.takeException(), isNull);
      },
    );
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
        await tester.tap(find.byType(DrawerButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tất cả công việc').last);
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
      await tester.tap(find.byType(DrawerButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tất cả công việc').last);
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
    await tester.tap(find.byType(DrawerButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Companion').last,
      150,
      scrollable: find.byType(Scrollable).last,
    );
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
