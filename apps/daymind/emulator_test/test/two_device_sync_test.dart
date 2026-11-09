import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:uuid/uuid.dart';
import 'package:daymind_smart/features/account_sync/application/sync_service.dart';
import 'package:daymind_smart/features/account_sync/data/firebase_rest.dart';
import 'package:daymind_smart/features/account_sync/data/firestore_gateway.dart';
import 'package:daymind_smart/features/account_sync/data/sync_store.dart';
import 'package:daymind_smart/features/account_sync/domain/account.dart';
import 'package:daymind_smart/features/account_sync/domain/sync_record.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:daymind_smart/features/recurrence/application/recurrence_service.dart';
import 'package:daymind_smart/features/recurrence/domain/recurrence.dart';
import 'package:daymind_smart/features/reminders/application/reminder_engine.dart';
import 'package:daymind_smart/features/reminders/domain/reminder.dart';

class PausedGateway extends FirestoreRestGateway {
  PausedGateway(super.endpoints, super.http);
  Completer<void>? entered, release;
  @override
  Future<String> write(
    AuthSession s,
    SyncRecord r, {
    String? expectedVersion,
  }) async {
    if (r.kind == SyncKind.task && entered != null) {
      entered!.complete();
      await release!.future;
      entered = null;
    }
    return super.write(s, r, expectedVersion: expectedVersion);
  }
}

void main() {
  if (Platform.environment['RUN_EMULATOR'] != 'true') {
    test(
      'explicit emulator opt-in required',
      () {},
      skip: 'Start local Auth/Firestore emulators.',
    );
    return;
  }
  zones.initializeTimeZones();
  late Directory workspace;
  late JsonTransport http;
  late FirebaseRestAuth auth;
  late PausedGateway cloud;
  late AuthSession user;
  late DaymindDatabase dbA, dbB;
  late SqliteTaskRepository a, b;
  late SyncStore sa, sb;
  late SyncService ca, cb;
  final now = DateTime.utc(2026, 1, 5);
  setUp(() async {
    http = JsonTransport(timeout: const Duration(seconds: 5));
    const endpoints = FirebaseEndpoints(host: '127.0.0.1');
    auth = FirebaseRestAuth(endpoints, http);
    cloud = PausedGateway(endpoints, http);
    user = await auth.signIn(
      '${const Uuid().v4()}@example.invalid',
      const Uuid().v4(),
      create: true,
    );
    workspace = await Directory.systemTemp.createTemp('daymind-two-devices-');
    dbA = DaymindDatabase(
      NativeDatabase.createInBackground(File('${workspace.path}/a.sqlite')),
    );
    dbB = DaymindDatabase(
      NativeDatabase.createInBackground(File('${workspace.path}/b.sqlite')),
    );
    a = SqliteTaskRepository(dbA, clock: () => now);
    b = SqliteTaskRepository(dbB, clock: () => now);
    sa = SyncStore(a, user.uid, clock: () => now);
    sb = SyncStore(b, user.uid, clock: () => now);
    await sa.bindOwner();
    await sb.bindOwner();
    ca = SyncService(
      store: sa,
      gateway: cloud,
      session: () async => user,
      deviceId: 'a',
      deviceName: 'Windows thử',
    );
    cb = SyncService(
      store: sb,
      gateway: cloud,
      session: () async => user,
      deviceId: 'b',
      deviceName: 'Android thử',
    );
  });
  tearDown(() async {
    await ca.stop();
    await cb.stop();
    ca.dispose();
    cb.dispose();
    try {
      await cloud.deleteData(user);
      await auth.deleteAccount(user);
    } finally {
      http.close();
      await dbA.close();
      await dbB.close();
      await workspace.delete(recursive: true);
    }
  });

  Future<void> synced(SyncService c) async {
    await c.sync();
    expect(c.message, isNull);
    expect(c.state, SyncState.idle);
  }

  Future<String> seed() async {
    final id = await a.save(
      TaskDraft(title: 'Bản đầu', dueAt: now.add(const Duration(hours: 10))),
    );
    await synced(ca);
    await synced(cb);
    return id;
  }

  Future<void> rename(SqliteTaskRepository r, String title) async {
    final t = (await r.list()).single;
    await r.save(
      TaskDraft.fromJson({...TaskDraft.fromTask(t).toJson(), 'title': title}),
      id: t.id,
      expectedRevision: t.revision,
    );
  }

  test('two SQLite devices converge without echoing physical revisions or reminder history', () async {
    await seed();
    await rename(b, 'Sửa ở điện thoại');
    await synced(cb);
    await synced(ca);
    await synced(cb);
    await synced(ca);
    expect((await a.list()).single.title, 'Sửa ở điện thoại');
    expect(await sa.capture(), 0);
    expect(await sb.capture(), 0);
    expect(await sa.pending(), isEmpty);
    expect(await sb.pending(), isEmpty);
    expect(await dbB.select(dbB.reminderEvents).get(), isEmpty);
    expect(
      (await cloud.fetchAll(user))
          .where((r) => r.record.kind == SyncKind.occurrence),
      isEmpty,
    );
  });
  test('divergent edits preserve both texts, block overwrite and resolve explicitly', () async {
    await seed();
    await rename(a, 'Giữ ở máy tính');
    await rename(b, 'Giữ ở điện thoại');
    await synced(ca);
    await cb.sync();
    expect(cb.state, SyncState.attention);
    expect((await b.list()).single.title, 'Giữ ở điện thoại');
    final h = (await sb.conflicts()).single;
    final conflict = (await sb.conflict(h.id))!;
    expect(conflict.local.data['title'], 'Giữ ở điện thoại');
    expect(conflict.remote!.record.data['title'], 'Giữ ở máy tính');
    await cb.sync();
    expect((await sb.conflicts()).length, 1);
    await cb.resolve(h.id, keepLocal: true);
    await synced(ca);
    expect((await a.list()).single.title, 'Giữ ở điện thoại');
    expect(await sb.conflicts(), isEmpty);
    expect((await sb.conflict(h.id))!.header.status, 'local');
    expect(
      (await sb.conflict(h.id))!.remote!.record.data['title'],
      'Giữ ở máy tính',
    );
  });
  test(
    'new edit while a write is in flight survives the older acknowledgement',
    () async {
      await seed();
      await rename(a, 'Đang gửi');
      cloud.entered = Completer<void>();
      cloud.release = Completer<void>();
      final entered = cloud.entered!.future;
      final flight = ca.sync();
      await entered;
      await rename(a, 'Sửa trong lúc gửi');
      await sa.capture();
      cloud.release!.complete();
      await flight;
      expect(
        (await sa.pending()).single.record.data['title'],
        'Sửa trong lúc gửi',
      );
      await synced(ca);
      await synced(cb);
      expect((await b.list()).single.title, 'Sửa trong lúc gửi');
    },
  );
  test('delete versus edit is a conflict; choosing deletion preserves trash and history', () async {
    await seed();
    final t = (await a.list()).single;
    await a.delete(t.id, t.revision);
    await rename(b, 'Sửa lúc máy khác xóa');
    await synced(ca);
    await cb.sync();
    final h = (await sb.conflicts()).single;
    expect((await b.list()).single.deletedAt, isNull);
    await cb.resolve(h.id, keepLocal: false);
    expect((await b.list()).single.deletedAt, isNotNull);
    expect((await b.list()).single.title, 'Bản đầu');
    expect(
      (await sb.conflict(h.id))!.local.data['title'],
      'Sửa lúc máy khác xóa',
    );
    final deleted = (await b.list()).single;
    await b.restore(deleted.id, deleted.revision);
    await synced(cb);
    await synced(ca);
    expect((await a.list()).single.deletedAt, isNull);
  });
  test('simultaneous future splits conflict as a whole series, not overlapping UUID documents', () async {
    final id = await a.save(
      TaskDraft(title: 'Chuỗi', dueAt: now.add(const Duration(hours: 10))),
    );
    final ra = RecurrenceService(a, clock: () => now),
        rb = RecurrenceService(b, clock: () => now);
    await ra.configure(
      id,
      const RepeatChange(
        enabled: true,
        spec: RepeatSpec(
          frequency: RepeatFrequency.daily,
          firstDate: '2026-01-05',
          zone: 'UTC',
          count: 4,
        ),
      ),
      TaskDraft.fromTask((await a.list()).single),
    );
    await ra.materialize(await a.list());
    await synced(ca);
    await synced(cb);
    await rb.reload();
    await ra.reload();
    Task chosen(RecurrenceService r, List<Task> roots) =>
        r.project(roots).singleWhere((t) => t.dueAt?.day == 6);
    final ta = chosen(ra, await a.list()), tb = chosen(rb, await b.list());
    await ra.edit(
      ta,
      TaskDraft.fromJson({
        ...TaskDraft.fromTask(ta).toJson(),
        'title': 'Nhánh máy tính',
      }),
      EditScope.future,
    );
    await rb.edit(
      tb,
      TaskDraft.fromJson({
        ...TaskDraft.fromTask(tb).toJson(),
        'title': 'Nhánh điện thoại',
      }),
      EditScope.future,
    );
    await synced(ca);
    await cb.sync();
    expect((await sb.conflicts()).single.kind, SyncKind.recurrence);
    await cb.resolve((await sb.conflicts()).single.id, keepLocal: false);
    await synced(ca);
    await synced(cb);
    await synced(ca);
    await ra.reload();
    await rb.reload();
    expect(chosen(ra, await a.list()).title, 'Nhánh máy tính');
    expect(chosen(rb, await b.list()).title, 'Nhánh máy tính');
    expect(
      rb.project(await b.list()).where((t) => t.deletedAt == null).length,
      4,
    );
    expect(await sa.capture(), 0);
    expect(await sb.capture(), 0);
  });
  test('replacing custom reminders on both devices conflicts and accepting remote invalidates old alarms', () async {
    final id = await seed();
    final ea = ReminderEngine(dbA, _Scheduler(), clock: () => now),
        eb = ReminderEngine(dbB, _Scheduler(), clock: () => now);
    await ea.configureTask(id, 'custom', [
      ReminderRule(
        id: 'rule-a',
        taskId: id,
        kind: ReminderKind.due,
        offsetMinutes: 10,
      ),
    ]);
    await eb.configureTask(id, 'custom', [
      ReminderRule(
        id: 'rule-b',
        taskId: id,
        kind: ReminderKind.due,
        offsetMinutes: 20,
      ),
    ]);
    await synced(ca);
    await cb.sync();
    expect((await sb.conflicts()).single.kind, SyncKind.reminderConfig);
    final revision = (await b.list()).single.revision;
    await cb.resolve((await sb.conflicts()).single.id, keepLocal: false);
    expect((await eb.rules(id)).single.id, 'rule-a');
    expect((await b.list()).single.revision, greaterThan(revision));
    expect(await sb.capture(), 0);
  });
  test('durable offline outbox survives database restart and rejects another owner', () async {
    final dir = await Directory.systemTemp.createTemp('daymind-offline-');
    final path = File('${dir.path}/offline.sqlite');
    var db = DaymindDatabase(NativeDatabase.createInBackground(path));
    try {
      var repo = SqliteTaskRepository(db, clock: () => now);
      var store = SyncStore(repo, user.uid, clock: () => now);
      await store.bindOwner();
      await repo.save(const TaskDraft(title: 'Chưa có mạng vẫn lưu'));
      await store.capture();

      await db.close();

      db = DaymindDatabase(NativeDatabase.createInBackground(path));
      repo = SqliteTaskRepository(db, clock: () => now);
      store = SyncStore(repo, user.uid, clock: () => now);

      expect(
        (await store.pending())
            .where((p) => p.record.kind == SyncKind.task)
            .single
            .record
            .data['title'],
        'Chưa có mạng vẫn lưu',
      );
      await expectLater(
        SyncStore(repo, 'other-owner').bindOwner(),
        throwsA(isA<AccountFailure>()),
      );
      final cycle = SyncService(
        store: store,
        gateway: cloud,
        session: () async => user,
        deviceId: 'offline',
        deviceName: 'Thử',
      );

      await synced(cycle);

      await cycle.stop();
      cycle.dispose();
      await synced(cb);

      expect((await b.list()).single.title, 'Chưa có mạng vẫn lưu');
    } finally {
      await db.close();

      await dir.delete(recursive: true);
    }
  });
}

// These tests never ask the operating system to show a notification.
class _Scheduler implements NotificationScheduler {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
