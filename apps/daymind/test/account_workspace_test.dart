import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:daymind_smart/app/workspace_host.dart';
import 'package:daymind_smart/main.dart' show WorkspaceApplication;
import 'package:daymind_smart/platform/secure_session_store.dart';
import 'package:daymind_smart/features/account_sync/domain/account.dart';
import 'package:daymind_smart/features/account_sync/domain/sync_record.dart';
import 'package:daymind_smart/features/account_sync/data/workspace_records.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/recurrence/application/recurrence_service.dart';
import 'package:daymind_smart/features/recurrence/domain/recurrence.dart';

class MemorySecure extends NativeSessionStore {
  final values = <String, String>{};
  bool failWrite = false;
  @override
  Future<String?> get(String key) async => values[key];
  @override
  Future<void> set(String key, String value) async {
    if (failWrite && key == 'session') {
      throw StateError('Test credential write failure');
    }
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class TestAuth implements AuthGateway {
  String? deleted;
  bool loseDeletionReply = false;
  AuthSession account(String email) => AuthSession(
    uid: email.split('@').first,
    email: email,
    idToken: 'test-id',
    refreshToken: 'test-refresh',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
  @override
  Future<AuthSession> signIn(
    String email,
    String password, {
    bool create = false,
  }) async => account(email);
  @override
  Future<AuthSession> refresh(AuthSession previous) async => previous;
  @override
  Future<AuthSession> reauthenticate(
    AuthSession session,
    String password,
  ) async {
    if (password != 'correct') {
      throw const AccountFailure('INVALID_PASSWORD', 'Mật khẩu chưa đúng.');
    }
    return session;
  }

  @override
  Future<void> deleteAccount(AuthSession session) async {
    if (deleted == session.uid) {
      throw const AccountFailure('USER_NOT_FOUND', 'Already removed.');
    }
    deleted = session.uid;
    if (loseDeletionReply) {
      loseDeletionReply = false;
      throw const AccountFailure('offline', 'Lost response', retryable: true);
    }
  }
}

class TestCloud implements SyncGateway {
  final data = <String, Map<String, RemoteRecord>>{};
  final removed = <String>{};
  final primaries = <String, PrimaryDevice>{};
  int count = 0;
  @override
  Future<void> provision(AuthSession session) async {
    if (removed.contains(session.uid)) {
      throw const AccountFailure('account_deleted', 'Đã xóa');
    }
    data.putIfAbsent(session.uid, () => {});
  }

  @override
  Future<bool> active(AuthSession session) async =>
      !removed.contains(session.uid);
  @override
  Future<List<RemoteRecord>> fetchAll(AuthSession session) async =>
      data[session.uid]!.values.toList();
  @override
  Future<RemoteRecord?> fetch(AuthSession s, String key) async =>
      data[s.uid]?[key];
  @override
  Future<String> write(
    AuthSession s,
    SyncRecord r, {
    String? expectedVersion,
  }) async {
    final old = data[s.uid]![r.key];
    if (old?.version != expectedVersion) {
      throw const AccountFailure('FAILED_PRECONDITION', 'Changed');
    }
    final version = 'opaque-${++count}';
    data[s.uid]![r.key] = RemoteRecord(r, version);
    return version;
  }

  @override
  Future<PrimaryDevice?> primary(AuthSession s) async => primaries[s.uid];
  @override
  Future<PrimaryDevice> claimPrimary(
    AuthSession s,
    String id, {
    String? expectedVersion,
  }) async {
    if (primaries[s.uid]?.version != expectedVersion) {
      throw const AccountFailure('FAILED_PRECONDITION', 'Changed');
    }
    return primaries[s.uid] = PrimaryDevice(id, 'primary-${++count}');
  }

  @override
  Future<void> registerDevice(AuthSession s, String id, String name) async {}
  @override
  Future<Map<String, String>> devices(AuthSession s) async => {};
  @override
  Future<void> deleteData(AuthSession s) async {
    removed.add(s.uid);
    data[s.uid]!.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  zones.initializeTimeZones();
  late Directory dir;
  late WorkspaceHost host;
  late TestCloud cloud;
  late TestAuth auth;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (_) async => 'UTC',
        );
    dir = await Directory.systemTemp.createTemp('daymind-account-workspace-');
    cloud = TestCloud();
    auth = TestAuth();
    host = WorkspaceHost(dir, MemorySecure(), auth, cloud);
    await host.start();
  });
  tearDown(() async {
    await host.shutdown();
    host.dispose();
    await dir.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          null,
        );
  });
  test('failed credential persistence restores usable local workspace and permits a later sign-in', () async {
    await host.controller!.save(
      const TaskDraft(title: 'Dữ liệu trước đăng nhập'),
    );
    final secure = host.secure as MemorySecure;
    secure.failWrite = true;
    await expectLater(
      host.signIn(
        'owner-a@example.invalid',
        'correct',
        create: true,
        copyLocal: false,
      ),
      throwsA(isA<AccountFailure>()),
    );
    expect(host.account, isNull);
    expect(host.controller!.tasks.single.title, 'Dữ liệu trước đăng nhập');
    await host.controller!.save(const TaskDraft(title: 'Vẫn lưu được sau lỗi'));
    expect(host.controller!.tasks.length, 2);
    secure.failWrite = false;
    await host.signIn(
      'owner-a@example.invalid',
      'correct',
      create: false,
      copyLocal: false,
    );
    await host.sync!.sync();
    expect(host.account!.uid, 'owner-a');
    expect(host.controller!.tasks, isEmpty);
  });
  test('account switch isolates tasks, private asset metadata and notification ledger; logout restores local', () async {
    final local = host.controller!;
    await local.save(const TaskDraft(title: 'Chỉ thuộc cục bộ'));
    await local.configure(
      (p) => p.copyWith(companionEnabled: false, assetName: '${'a' * 64}.png'),
    );
    await host.signIn(
      'owner-a@example.invalid',
      'correct',
      create: true,
      copyLocal: false,
    );
    await host.sync!.sync();
    expect(host.controller!.tasks, isEmpty);
    expect(host.controller!.preferences.assetName, isNull);
    expect(host.controller!.preferences.companionEnabled, isTrue);
    expect(host.controller!.reminders!.preferences.primaryDevice, isFalse);
    await host.controller!.save(const TaskDraft(title: 'Chỉ thuộc A'));
    await host.sync!.sync();
    await host.signOut();
    expect(host.controller!.tasks.single.title, 'Chỉ thuộc cục bộ');
    expect(host.controller!.preferences.assetName, '${'a' * 64}.png');
    await host.signIn(
      'owner-b@example.invalid',
      'correct',
      create: true,
      copyLocal: false,
    );
    await host.sync!.sync();
    expect(host.controller!.tasks, isEmpty);
    expect(host.controller!.preferences.assetName, isNull);
    expect(
      await host.controller!.repository.db
          .select(host.controller!.repository.db.reminderEvents)
          .get(),
      isEmpty,
    );
    await host.signOut();
    await host.signIn(
      'owner-a@example.invalid',
      'correct',
      create: false,
      copyLocal: false,
    );
    await host.sync!.sync();
    expect(host.controller!.tasks.single.title, 'Chỉ thuộc A');
    expect(
      workspacePath(dir.path, 'owner-a'),
      isNot(workspacePath(dir.path, 'owner-b')),
    );
    expect(workspacePath(dir.path, 'owner-a'), isNot(contains('owner-a')));
  });
  test('explicit copy preserves recurring exceptions while leaving original and existing account work intact', () async {
    final local = host.controller!;
    final start = DateTime.now().toUtc().add(const Duration(hours: 2));
    final id = await local.save(
      TaskDraft(title: 'Chuỗi cục bộ', dueAt: start),
      repetition: RepeatChange(
        enabled: true,
        spec: RepeatSpec(
          frequency: RepeatFrequency.daily,
          firstDate: dateKey(start),
          zone: 'UTC',
          count: 3,
        ),
      ),
    );
    final first = local.visibleTasks.firstWhere((t) => t.seriesId == id);
    await local.toggle(first);
    await host.signIn(
      'owner-a@example.invalid',
      'correct',
      create: true,
      copyLocal: true,
    );
    await host.sync!.sync();
    expect(host.controller!.tasks.single.id, isNot(id));
    expect(
      host.controller!.visibleTasks
          .where((t) => t.status == TaskStatus.completed)
          .length,
      1,
    );
    expect(host.controller!.visibleTasks.length, 3);
    expect(
      (await WorkspaceRecords(
        host.controller!.repository,
      ).read()).values.where((r) => r.kind == SyncKind.occurrence).length,
      1,
    );
    await host.signOut();
    expect(host.controller!.tasks.single.id, id);
    await host.signIn(
      'owner-a@example.invalid',
      'correct',
      create: false,
      copyLocal: false,
    );
    await host.sync!.sync();
    expect(host.controller!.tasks.length, 1);
  });
  test('wrong password cannot mark an account deleted; verified deletion clears only account workspace', () async {
    await host.controller!.save(const TaskDraft(title: 'Giữ bản cục bộ'));
    await host.signIn(
      'owner-a@example.invalid',
      'correct',
      create: true,
      copyLocal: false,
    );
    await host.sync!.sync();
    await host.controller!.save(const TaskDraft(title: 'Dữ liệu tài khoản'));
    final accountPath = workspacePath(dir.path, 'owner-a');
    await expectLater(
      host.deleteAccount('wrong'),
      throwsA(isA<AccountFailure>()),
    );
    expect(cloud.removed, isEmpty);
    expect(auth.deleted, isNull);
    expect(host.account?.uid, 'owner-a');
    await host.deleteAccount('correct');
    expect(auth.deleted, 'owner-a');
    expect(cloud.removed, contains('owner-a'));
    expect(await Directory(accountPath).exists(), isFalse);
    expect(host.account, isNull);
    expect(host.controller!.tasks.single.title, 'Giữ bản cục bộ');
  });
  test('lost account-deletion reply can be retried without resurrecting data or losing local profile', () async {
    await host.controller!.save(const TaskDraft(title: 'Giữ cục bộ khi xóa'));
    await host.signIn(
      'owner-a@example.invalid',
      'correct',
      create: true,
      copyLocal: false,
    );
    await host.sync!.sync();
    auth.loseDeletionReply = true;
    await expectLater(
      host.deleteAccount('correct'),
      throwsA(isA<AccountFailure>()),
    );
    expect(cloud.removed, contains('owner-a'));
    expect(host.controller!.reminders!.preferences.primaryDevice, isFalse);
    await host.deleteAccount('correct');
    expect(host.account, isNull);
    expect(host.controller!.tasks.single.title, 'Giữ cục bộ khi xóa');
  });
  testWidgets(
    'account screen fits a phone at 200% text and validates without sending credentials',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(WorkspaceApplication(host: host));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cài đặt'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Tài khoản & đồng bộ'), 350);
      await tester.tap(find.text('Tài khoản & đồng bộ'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('account-email')),
        350,
      );
      expect(find.byKey(const Key('account-email')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('account-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Nhập email hợp lệ.'), findsOneWidget);
      expect(host.account, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
