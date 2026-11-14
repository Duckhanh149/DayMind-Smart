import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import 'package:daymind_smart/features/account_sync/data/firebase_rest.dart';
import 'package:daymind_smart/features/account_sync/data/firestore_gateway.dart';
import 'package:daymind_smart/features/account_sync/domain/account.dart';
import 'package:daymind_smart/features/account_sync/domain/sync_record.dart';
import 'package:daymind_smart/features/recurrence/domain/recurrence.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';
import 'package:timezone/data/latest.dart' as zones;

void main() {
  if (Platform.environment['RUN_EMULATOR'] != 'true') {
    test(
      'explicit emulator opt-in required',
      () {},
      skip: 'Requires Auth/Firestore emulators.',
    );
    return;
  }
  zones.initializeTimeZones();
  late JsonTransport http;
  late FirebaseRestAuth auth;
  late FirestoreRestGateway cloud;
  late AuthSession user;
  const endpoints = FirebaseEndpoints(host: '127.0.0.1');
  setUp(() async {
    http = JsonTransport();
    auth = FirebaseRestAuth(endpoints, http);
    cloud = FirestoreRestGateway(endpoints, http);
    user = await auth.signIn(
      '${const Uuid().v4()}@example.invalid',
      const Uuid().v4(),
      create: true,
    );
    await cloud.provision(user);
  });
  tearDown(() async {
    await cloud.deleteData(user);
    await auth.deleteAccount(user);
    http.close();
  });
  Future<void> raw(SyncRecord id, String payload) => http
      .request(
        'POST',
        endpoints.firestore(':commit'),
        token: user.idToken,
        body: {
          'writes': [
            {
              'update': {
                'name':
                    '${endpoints.documentPrefix}/users/${user.uid}/records/${id.key}',
                'fields': {
                  'schema': {'integerValue': '1'},
                  'kind': {'stringValue': id.kind.name},
                  'recordId': {'stringValue': id.id},
                  'payload': {'stringValue': payload},
                  'deleted': {'booleanValue': false},
                },
              },
            },
          ],
        },
      )
      .then((_) {});
  SyncRecord small() => SyncRecord(
    kind: SyncKind.task,
    id: 'budget-task',
    data: {
      'title': 'An toàn',
      'createdAt': '2026-01-05T00:00:00Z',
      'updatedAt': '2026-01-05T00:00:00Z',
    },
  );
  test(
    'large compressed rulesets round-trip through actual Firestore rules',
    () async {
      final record = SyncRecord(
        kind: SyncKind.recurrence,
        id: 'series-budget',
        data: {
          'taskId': 'series-budget',
          'rules': [
            for (var i = 0; i < 40; i++)
              RecurrenceRule(
                id: 'segment-$i',
                taskId: 'series-budget',
                spec: const RepeatSpec(
                  frequency: RepeatFrequency.daily,
                  firstDate: '2026-01-05',
                  zone: 'UTC',
                ),
                template: TaskDraft(
                  title: 'Đoạn $i',
                  description: 'x' * 9000,
                  dueAt: DateTime.utc(2026, 1, 5, 10),
                ),
                templateDate: '2026-01-05',
                enabled: false,
              ).toJson()..remove('revision'),
          ],
        },
      );
      expect(
        utf8.encode(canonicalJson(record.data)).length,
        greaterThan(32768),
      );
      await cloud.write(user, record);
      expect(
        (await cloud.fetch(user, record.key))!.record.contentHash,
        record.contentHash,
      );
    },
  );
  test('compressed expansion beyond 4 MiB and malformed compressed data are rejected', () async {
    final record = small();
    await raw(
      record,
      'z1:${base64Encode(ZLibEncoder().convert(utf8.encode('x' * (5 * 1024 * 1024))))}',
    );
    await expectLater(
      cloud.fetch(user, record.key),
      throwsA(
        isA<AccountFailure>().having((e) => e.code, 'code', 'record_limit'),
      ),
    );
    await raw(record, 'z1:not-valid-base64');
    await expectLater(cloud.fetchAll(user), throwsA(isA<AccountFailure>()));
  });
  test(
    'an unrecognized payload field is rejected before it reaches local storage',
    () async {
      final record = small();
      await raw(
        record,
        jsonEncode({...record.data, 'privateToken': 'must-not-be-imported'}),
      );
      await expectLater(
        cloud.fetchAll(user),
        throwsA(
          isA<AccountFailure>().having((e) => e.code, 'code', 'invalid_record'),
        ),
      );
    },
  );
}
