import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';
import 'package:daymind_smart/features/companion/domain/floating_settings.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/platform/floating_companion.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  test('floating defaults are off and corrupted geometry is rejected before persistence', () {
    final s = FloatingCompanionSettings.fromJson(null);
    expect([s.enabled, s.topmost, s.clickThrough], [false, false, false]);
    expect(FloatingCompanionSettings.fromJson(s.toJson()).toJson(), s.toJson());
    for (final bad in [
      {'size': 10},
      {'x': 100},
      {'x': 100001, 'y': 0},
    ]) {
      expect(
        () => FloatingCompanionSettings.fromJson(bad),
        throwsA(isA<CompanionValidation>()),
      );
    }
    expect(
      s.copy(x: 10, y: 20, clickThrough: true).copy(resetPosition: true).x,
      isNull,
    );
  });

  late Directory temp;
  late DaymindDatabase db;
  late WorkspaceController c;
  late FloatingCompanionService service;
  late DateTime now;
  final calls = <MethodCall>[];
  var nativeState = <String, dynamic>{};
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(condition(), isTrue);
  }

  setUp(() async {
    calls.clear();
    nativeState = {'visible': true, 'reason': ''};
    temp = await Directory.systemTemp.createTemp('daymind-floating-');
    db = DaymindDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 11, 10, 10);
    c = WorkspaceController(
      SqliteTaskRepository(db),
      StaticAssetImporter(temp),
      clock: () => now,
    );
    await c.load();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      FloatingCompanionService.channel,
      (call) async {
        if (call.method == 'state') return nativeState;
        calls.add(call);
        return null;
      },
    );
    service = FloatingCompanionService(c)..start();
  });
  tearDown(() async {
    await service.stop();
    await c.drain();
    c.dispose();
    await db.close();
    await temp.delete(recursive: true);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      FloatingCompanionService.channel,
      null,
    );
  });
  test('disabled floating sends no artwork; opt-in uses safe geometry and original fallback', () async {
    await until(() => calls.isNotEmpty);
    expect(calls.map((v) => v.method), ['close']);
    await c.updateFloating((s) => s.copy(enabled: true));
    await until(() => calls.any((v) => v.method == 'configure'));
    final data = calls.last.arguments as Map;
    expect(data['topmost'], isFalse);
    expect(data['clickThrough'], isFalse);
    expect(data['image'], isEmpty);
    expect(data.keys, isNot(contains('path')));
    expect(data.keys, isNot(contains('ownerId')));
    await c.updateFloating((s) => s.copy(x: -120, y: 320, clickThrough: true));
    await until(() => (calls.last.arguments as Map?)?['x'] == -120);
    expect((calls.last.arguments as Map)['image'], isNull);
    await c.updateFloating(
      (s) => s.copy(resetPosition: true, clickThrough: false),
    );
    await until(() => !(calls.last.arguments as Map).containsKey('x'));
    expect((calls.last.arguments as Map)['clickThrough'], isFalse);
  });
  test('animated atlas is sent once per art revision, low resource uses preview, stop closes before removal', () async {
    final name = await c.importer.installPrepared(
      await c.importer.prepareCharacter(
        File('test/fixtures/three_frames.gif'),
        'leaf.gif',
      ),
      rightsConfirmed: true,
    );
    await c.configure((p) => p.copyWith(assetName: name));
    await c.updateFloating((s) => s.copy(enabled: true));
    await until(() => calls.any((v) => v.method == 'configure'));
    final normal = calls.last.arguments as Map;
    expect(normal['frames'], hasLength(3));
    expect(normal['sequence'], [0, 1, 2]);
    expect(normal['image'], isNotEmpty);
    expect(normal.toString(), isNot(contains(temp.path)));
    final before = calls.length;
    c.expression = CompanionExpression.happy;
    await c.refreshFromNative();
    await until(() => calls.length > before);
    expect((calls.last.arguments as Map).containsKey('image'), isFalse);
    await c.updateCompanionLayout((s) => s.copy(lowResource: true));
    await until(() => (calls.last.arguments as Map)['lowResource'] == true);
    expect((calls.last.arguments as Map)['frames'], isEmpty);
    expect((calls.last.arguments as Map)['image'], isNotEmpty);
    await service.stop();
    expect(calls.last.method, 'close');
    final count = calls.length;
    await c.removeCompanionAsset(name);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(calls.length, count);
    expect(c.importer.installed(), isEmpty);
  });
  test('accepted same-expression cues replay natively while cooldown and sync reload do not', () async {
    await c.updateFloating((s) => s.copy(enabled: true));
    await until(() => calls.any((v) => v.method == 'configure'));
    const cue = CompanionCue(
      CompanionEvent.reminderDue,
      'Đến giờ',
      task: 'Đọc sách',
    );
    now = now.add(
      const Duration(seconds: 31),
    ); // Initial greeting has cooled down.
    c.foregroundReminder(cue);
    await until(
      () =>
          (calls.last.arguments as Map)['motionRevision'] ==
          c.companionMotionSequence,
    );
    final first = c.companionMotionSequence;
    expect(c.companionAnnouncementSequence, c.inAppSequence);
    expect((calls.last.arguments as Map).containsKey('image'), isFalse);
    c.foregroundReminder(cue);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.companionMotionSequence, first);
    expect(c.companionAnnouncementSequence, -1);
    await c.refreshFromSync();
    expect(c.companionMotionSequence, first);
    now = now.add(const Duration(seconds: 31));
    c.foregroundReminder(cue);
    expect(c.companionMotionSequence, first + 1);
    await until(
      () => (calls.last.arguments as Map)['motionRevision'] == first + 1,
    );
    expect((calls.last.arguments as Map).containsKey('image'), isFalse);
  });
  test(
    'unchanged artwork still refreshes the real OS hide reason for settings',
    () async {
      await c.updateFloating((s) => s.copy(enabled: true));
      await until(() => c.floatingStatus == 'Nhân vật nổi đang hiển thị.');
      final count = calls.where((v) => v.method == 'configure').length;
      nativeState = {'visible': false, 'reason': 'focus'};
      await c.refreshFromSync();
      await until(
        () => c.floatingStatus?.contains('Windows đang hạn chế') == true,
      );
      expect(calls.where((v) => v.method == 'configure'), hasLength(count));
    },
  );
}
