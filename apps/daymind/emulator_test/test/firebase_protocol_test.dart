import 'dart:io';

import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import 'package:daymind_smart/features/account_sync/domain/account.dart';
import 'package:daymind_smart/features/account_sync/domain/sync_record.dart';
import 'package:daymind_smart/features/account_sync/data/firebase_rest.dart';
import 'package:daymind_smart/features/account_sync/data/firestore_gateway.dart';

void main() {
  if (Platform.environment['RUN_EMULATOR'] != 'true') {
    test(
      'explicit emulator opt-in required',
      () {},
      skip: 'Run with RUN_EMULATOR=true and local Auth/Firestore emulators.',
    );
    return;
  }
  late JsonTransport http;
  late FirebaseRestAuth auth;
  late FirestoreRestGateway cloud;
  late AuthSession a, b;
  late String password;
  const endpoints = FirebaseEndpoints(host: '127.0.0.1');
  setUp(() async {
    http = JsonTransport(timeout: const Duration(seconds: 5));
    auth = FirebaseRestAuth(endpoints, http);
    cloud = FirestoreRestGateway(endpoints, http);
    password = const Uuid().v4();
    a = await auth.signIn(
      '${const Uuid().v4()}@example.invalid',
      password,
      create: true,
    );
    b = await auth.signIn(
      '${const Uuid().v4()}@example.invalid',
      password,
      create: true,
    );
    await cloud.provision(a);
    await cloud.provision(b);
  });
  tearDown(() async {
    for (final session in [a, b]) {
      try {
        await cloud.deleteData(session);
        await auth.deleteAccount(session);
      } on AccountFailure {
        /* Test may already have deleted the same synthetic account. */
      }
    }
    http.close();
  });
  SyncRecord task(String title) => SyncRecord(
    kind: SyncKind.task,
    id: 'protocol-task',
    data: {
      'title': title,
      'createdAt': '2026-01-05T00:00:00.000Z',
      'updatedAt': '2026-01-05T00:00:00.000Z',
    },
  );
  test(
    'real emulator sign-in, refresh and reauthentication keep the same owner',
    () async {
      final signed = await auth.signIn(a.email, password),
          refreshed = await auth.refresh(a);
      expect(signed.uid, a.uid);
      expect(refreshed.uid, a.uid);
      expect(refreshed.refreshDue(DateTime.now()), isFalse);
      expect((await auth.reauthenticate(a, password)).uid, a.uid);
      await expectLater(
        auth.signIn(a.email, 'incorrect-password'),
        throwsA(isA<AccountFailure>()),
      );
    },
  );
  test('real Firestore CAS preserves exact updateTime and denies foreign/anonymous access', () async {
    final initial = task('Bản đầu');
    final version = await cloud.write(a, initial);
    final loaded = await cloud.fetch(a, initial.key);
    expect(loaded!.version, version);
    expect(loaded.record.contentHash, initial.contentHash);
    final next = await cloud.write(
      a,
      task('Bản sau'),
      expectedVersion: version,
    );
    expect(next, isNot(version));
    await expectLater(
      cloud.write(
        a,
        task('Bản cũ không được ghi đè'),
        expectedVersion: version,
      ),
      throwsA(
        isA<AccountFailure>().having(
          (e) => e.code,
          'code',
          'FAILED_PRECONDITION',
        ),
      ),
    );
    expect(
      (await cloud.fetch(a, initial.key))!.record.data['title'],
      'Bản sau',
    );
    final path = endpoints.firestore('/users/${a.uid}/records/${initial.key}');
    await expectLater(
      http.request('GET', path, token: b.idToken),
      throwsA(
        isA<AccountFailure>().having(
          (e) => e.code,
          'code',
          'PERMISSION_DENIED',
        ),
      ),
    );
    await expectLater(
      http.request('GET', path),
      throwsA(isA<AccountFailure>()),
    );
  });
  test('primary-device compare-and-set has one winner and preserves the latest choice', () async {
    await cloud.registerDevice(a, 'device-a', 'Máy tính thử');
    await cloud.registerDevice(a, 'device-b', 'Điện thoại thử');
    expect((await cloud.devices(a)).length, 2);
    final first = await cloud.claimPrimary(a, 'device-a');
    await expectLater(
      cloud.claimPrimary(a, 'device-b'),
      throwsA(isA<AccountFailure>()),
    );
    final second = await cloud.claimPrimary(
      a,
      'device-b',
      expectedVersion: first.version,
    );
    await expectLater(
      cloud.claimPrimary(a, 'device-a', expectedVersion: first.version),
      throwsA(isA<AccountFailure>()),
    );
    expect((await cloud.primary(a))!.id, 'device-b');
    expect(second.id, 'device-b');
  });
  test('account deletion marker blocks stale clients from resurrecting private records', () async {
    final record = task('Không được hồi sinh');
    await cloud.write(a, record);
    await cloud.deleteData(a);
    expect(await cloud.active(a), isFalse);
    expect(await cloud.fetchAll(a), isEmpty);
    await expectLater(cloud.write(a, record), throwsA(isA<AccountFailure>()));
    await expectLater(
      cloud.provision(a),
      throwsA(
        isA<AccountFailure>().having((e) => e.code, 'code', 'account_deleted'),
      ),
    );
    final verified = await auth.reauthenticate(a, password);
    await auth.deleteAccount(verified);
    await expectLater(cloud.write(a, record), throwsA(isA<AccountFailure>()));
  });
}
