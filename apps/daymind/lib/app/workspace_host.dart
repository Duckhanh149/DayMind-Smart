import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../features/account_sync/application/sync_service.dart';
import '../features/account_sync/data/copy_workspace.dart';
import '../features/account_sync/data/sync_store.dart';
import '../features/account_sync/data/workspace_records.dart';
import '../features/account_sync/domain/account.dart';
import '../features/account_sync/domain/sync_record.dart';

import 'package:uuid/uuid.dart';

import '../features/companion/data/asset_importer.dart';
import '../features/reminders/application/reminder_coordinator.dart';
import '../features/reminders/application/reminder_engine.dart';
import '../features/reminders/domain/reminder.dart';
import '../features/tasks/data/database.dart';
import '../platform/notification_scheduler.dart';
import '../platform/secure_session_store.dart';
import '../platform/window_lifecycle.dart';
import 'controller.dart';

final workspaceHostProvider = Provider<WorkspaceHost?>((ref) => null);

String workspacePath(String support, String? uid) => uid == null
    ? support
    : p.join(support, 'accounts', sha256.convert(utf8.encode(uid)).toString());

class WorkspaceHost extends ChangeNotifier {
  WorkspaceHost(this.support, this.secure, this.auth, this.gateway);
  final Directory support;
  final NativeSessionStore secure;
  final AuthGateway auth;
  final SyncGateway gateway;
  WorkspaceController? controller;
  PlatformNotificationScheduler? _scheduler;
  SyncService? sync;
  StreamSubscription<void>? _syncListener;
  AuthSession? account;
  WindowLifecycle? window;
  bool switching = false;
  int generation = 0;
  String? sessionError;
  late String deviceId;
  Timer? _editTimer;
  Future<void> _tail = Future.value();
  Future<AuthSession>? _refresh;
  Future<void> shutdown() async {
    _editTimer?.cancel();
    await _tail;
    await sync?.stop();
    await controller?.drain();
    await controller?.reminders?.stop();
    await _scheduler?.deactivate();
    await _syncListener?.cancel();
    sync?.dispose();
    controller?.dispose();
    if (controller != null) await controller!.repository.db.close();
    window?.dispose();
  }

  Future<void> start() async {
    try {
      deviceId = await secure.installationId();
      account = await secure.read();
    } catch (_) {
      deviceId = const Uuid().v4();
      sessionError = 'Chưa đọc được kho đăng nhập của hệ điều hành. Bạn vẫn dùng được dữ liệu cục bộ.';
    }
    if (Platform.isWindows) {
      window = WindowLifecycle();
      window!.onVisibility = (visible) =>
          controller?.reminders?.setWindowVisible(visible);
    }
    await _switch(account, persist: false);
    if (window != null) {
      await window!.start(controller!.preferences.windowsTrayEnabled);
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final f = _tail.then((_) async {
      switching = true;
      notifyListeners();
      try {
        return await action();
      } finally {
        switching = false;
        notifyListeners();
      }
    });
    _tail = f.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return f;
  }

  Future<AuthSession> session() async {
    final s = account;
    if (s == null) {
      throw const AccountFailure('signed_out', 'Hãy đăng nhập để đồng bộ.');
    }
    if (!s.refreshDue(DateTime.now().toUtc())) return s;
    if (_refresh != null) return _refresh!;
    final f = () async {
      final next = await auth.refresh(s);
      if (next.uid != s.uid) {
        throw const AccountFailure(
          'owner_mismatch',
          'Phiên đăng nhập đã đổi tài khoản.',
        );
      }
      await secure.write(next);
      account = next;
      return next;
    }();
    _refresh = f;
    return f.whenComplete(() => _refresh = null);
  }

  Future<void> signIn(
    String email,
    String password, {
    required bool create,
    required bool copyLocal,
  }) => _serial(() async {
    if (account != null) {
      throw const AccountFailure(
        'already_signed_in',
        'Hãy đăng xuất trước khi đổi tài khoản.',
      );
    }
    final next = await auth.signIn(email, password, create: create);
    await gateway.provision(next);
    final source = copyLocal
        ? (await WorkspaceRecords(
            controller!.repository,
          ).read()).values.toList()
        : null;
    await _switch(next, copy: source);
  });
  Future<void> signOut() => _serial(() => _switch(null));

  Future<void> deleteAccount(String password) => _serial(() async {
    final current = account;
    if (current == null) {
      throw const AccountFailure('signed_out', 'Bạn chưa đăng nhập.');
    }
    final records = controller!.recurrence.records;
    final pending = await records.get('account', 'deletion');
    final completed =
        pending?['ownerId'] == current.uid && pending?['authDeleted'] == true;
    if (!completed) {
      final recent =
          pending?['ownerId'] == current.uid &&
          pending?['cleanupComplete'] == true &&
          DateTime.now()
                  .toUtc()
                  .difference(DateTime.parse(pending!['verifiedAt'] as String))
                  .inMinutes <
              5 &&
          !current.refreshDue(DateTime.now().toUtc());
      // Initial deletion always reauthenticates. A recent retry can reuse that verified session.
      final verified = recent
          ? current
          : await auth.reauthenticate(await session(), password);
      await secure.write(verified);
      account = verified;
      await sync?.stop();
      await records.put('notifications', 'cloud_primary', {'here': false});
      await controller!.reminders?.applyPrimary(false);
      await gateway.deleteData(verified);
      final receipt = {
        'ownerId': verified.uid,
        'cleanupComplete': true,
        'verifiedAt': DateTime.now().toUtc().toIso8601String(),
        'authDeleted': false,
      };
      await records.put('account', 'deletion', receipt);
      try {
        await auth.deleteAccount(verified);
      } on AccountFailure catch (e) {
        if (e.code != 'USER_NOT_FOUND') rethrow;
      }
      await records.put('account', 'deletion', {
        ...receipt,
        'authDeleted': true,
      });
    }
    final directory = Directory(workspacePath(support.path, current.uid));
    await _switch(null);
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<void> notificationDevice(bool enabled) async {
    final c = controller!, service = sync;
    if (service == null) {
      await c.reminders!.applyPrimary(enabled);
      return;
    }
    if (enabled) {
      await service.claimPrimary(); // online CAS required before enabling.
    }
    await c.recurrence.records.put('notifications', 'local_device', {
      'enabled': enabled,
    });
    await c.reminders!.applyPrimary(enabled && service.primaryHere);
  }

  Future<void> _switch(
    AuthSession? next, {
    List<SyncRecord>? copy,
    bool persist = true,
  }) async {
    final directory = Directory(workspacePath(support.path, next?.uid));
    await directory.create(recursive: true);
    final path = p.join(directory.path, 'daymind.sqlite');
    final db = DaymindDatabase(NativeDatabase.createInBackground(File(path)));
    final c = WorkspaceController(
      SqliteTaskRepository(db),
      StaticAssetImporter(Directory(p.join(directory.path, 'characters'))),
    );
    try {
      if (next != null) {
        await SyncStore(c.repository, next.uid).bindOwner();
        if (copy != null) {
          await copyWorkspace(copy, WorkspaceRecords(c.repository));
        }
        // A cached primary decision is device-specific and persists across restarts.
        final choice = await c.recurrence.records.get(
          'notifications',
          'cloud_primary',
        );
        final prefs = NotificationPreferences.fromJson(
          await c.recurrence.records.get('notifications', 'settings') ?? {},
        );
        await ReminderEngine(db, _NoScheduler()).configure(
          NotificationPreferences.fromJson({
            ...prefs.toJson(),
            'primaryDevice':
                choice?['here'] == true &&
                await c.recurrence.records.get('account', 'deletion') == null &&
                (await c.recurrence.records.get(
                      'notifications',
                      'local_device',
                    ))?['enabled'] !=
                    false,
          }),
        );
      }
      await c.load();
    } catch (_) {
      c.dispose();
      await db.close();
      rethrow;
    }
    _editTimer?.cancel();
    final old = controller;
    final oldOpen = _scheduler?.onOpen;
    try {
      await sync?.stop();
      await old?.drain();
      await old?.reminders?.stop();
      // Never switch native database paths until old alarms are gone.
      await _scheduler?.deactivate();
      if (persist) {
        if (next == null) {
          await secure.clear();
        } else {
          await secure.write(next);
        }
      }
    } catch (_) {
      c.dispose();
      await db.close();
      // A failed OS credential write must not leave the previous workspace locked.
      old?.resumeWrites();
      if (old != null && _scheduler != null) {
        _scheduler!.onOpen = oldOpen;
        final zone = await _scheduler!.initialize(
          p.join(workspacePath(support.path, account?.uid), 'daymind.sqlite'),
        );
        await old.reminders?.resume(zone);
        if (sync != null) unawaited(sync!.resume());
      }
      throw const AccountFailure(
        'profile_switch',
        'Chưa chuyển được tài khoản. Không gian trước vẫn được giữ; hãy thử lại sau khi kiểm tra quyền lưu trữ.',
      );
    }
    await _syncListener?.cancel();
    sync?.dispose();
    sync = null;
    old?.dispose();
    if (old != null) await old.repository.db.close();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    controller = c;
    account = next;
    generation++;
    if (window != null) {
      c.attachWindow(window!);
      await window!.configure(c.preferences.windowsTrayEnabled);
    }
    final scheduler = PlatformNotificationScheduler();
    _scheduler = scheduler;
    scheduler.onOpen = () {
      c.openNotifications();
      if (window != null) unawaited(window!.show());
    };
    final zone = await scheduler.initialize(path);
    final reminders = ReminderCoordinator(
      ReminderEngine(db, scheduler),
      c.reminderTasks,
      readTimezone: scheduler.localTimezone,
      onNativeChange: c.refreshFromNative,
      onInApp: (text) => c.dialogue = text,
    );
    c.attachReminders(reminders);
    reminders.onPrimaryRequest = notificationDevice;
    await reminders.start(zone);
    if (next != null) {
      final service = SyncService(
        store: SyncStore(c.repository, next.uid),
        gateway: gateway,
        session: session,
        deviceId: deviceId,
        deviceName: Platform.isWindows
            ? 'DayMind trên Windows'
            : 'DayMind trên Android',
        onChanged: c.refreshFromSync,
        onPrimary: (here) async {
          await c.recurrence.records.put('notifications', 'cloud_primary', {
            'here': here,
          });
          final enabled =
              (await c.recurrence.records.get(
                'notifications',
                'local_device',
              ))?['enabled'] !=
              false;
          await reminders.applyPrimary(here && enabled);
        },
      );
      sync = service;
      _syncListener = service.changes.listen((_) => notifyListeners());
      c.onLocalChange = () {
        service.markLocalChange();
        _editTimer?.cancel();
        _editTimer = Timer(
          const Duration(milliseconds: 500),
          () => unawaited(service.sync()),
        );
      };
      unawaited(service.start());
    }
    notifyListeners();
  }
}

/// Used only to persist preferences before native notification initialization.
class _NoScheduler implements NotificationScheduler {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
