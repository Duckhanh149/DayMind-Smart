import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';

void main() {
  late DaymindDatabase db;
  late WorkspaceController controller;
  late Directory temp;
  setUp(() async {
    db = DaymindDatabase(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('daymind-controller-');
    controller = WorkspaceController(
      SqliteTaskRepository(db),
      StaticAssetImporter(temp),
    );
    await controller.load();
  });
  tearDown(() async {
    controller.dispose();
    await db.close();
    await temp.delete(recursive: true);
  });
  test('queued setting updates preserve changes to different fields', () async {
    await Future.wait([
      controller.configure((prefs) => prefs.copyWith(theme: 'dark')),
      controller.configure((prefs) => prefs.copyWith(companionEnabled: false)),
    ]);
    expect(controller.preferences.theme, 'dark');
    expect(controller.preferences.companionEnabled, false);
  });
  test(
    'failed write keeps existing data, unlocks UI and allows the next save',
    () async {
      await controller.save(const TaskDraft(title: 'Bản hợp lệ'));
      await expectLater(
        controller.save(const TaskDraft(title: ' ')),
        throwsA(isA<ValidationException>()),
      );
      expect(controller.busy, false);
      expect(controller.tasks.single.title, 'Bản hợp lệ');
      await controller.save(const TaskDraft(title: 'Lưu tiếp được'));
      expect(controller.tasks.length, 2);
    },
  );
  test('tasks work normally with companion turned off', () async {
    await controller.configure(
      (prefs) => prefs.copyWith(companionEnabled: false),
    );
    await controller.save(const TaskDraft(title: 'Độc lập với Companion'));
    await controller.toggle(controller.tasks.single);
    expect(controller.tasks.single.status, TaskStatus.completed);
    expect(controller.preferences.companionEnabled, false);
  });
}
