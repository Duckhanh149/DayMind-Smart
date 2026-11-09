import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:daymind_smart/features/account_sync/domain/account.dart';
import 'package:daymind_smart/features/account_sync/domain/sync_record.dart';
import 'package:daymind_smart/features/recurrence/domain/recurrence.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';

void main() {
  zones.initializeTimeZones();
  Map<String, dynamic> task() => {
    'title': 'Bản gốc',
    'createdAt': '2026-01-05T00:00:00Z',
    'updatedAt': '2026-01-05T00:00:00Z',
  };
  test('hot validation remains stable across long-running sync sessions', () {
    final sample = SyncRecord(
      kind: SyncKind.task,
      id: 'hot-task',
      data: task(),
    );
    final category = SyncRecord(
      kind: SyncKind.category,
      id: 'hot-category',
      data: {'name': 'Thử tối ưu', 'color': 0xff6b8b72},
    );
    SyncRecord latest = sample;
    for (var i = 0; i < 10000; i++) {
      latest = SyncRecord.fromJson((i.isEven ? category : sample).toJson());
    }
    expect(latest.contentHash, sample.contentHash);
  });
  test('normalization is stable and a record cannot be mutated through source or nested references', () {
    final data = task(),
        r = SyncRecord(kind: SyncKind.task, id: 't', data: task());
    final copy = SyncRecord(kind: SyncKind.task, id: 't', data: data);
    data['title'] = 'Đổi nguồn';
    expect(copy.contentHash, r.contentHash);
    expect(() => copy.data['title'] = 'Ghi lén', throwsUnsupportedError);
    expect(SyncRecord.fromJson(r.toJson()).contentHash, r.contentHash);
  });
  test(
    'invalid dates, unknown schemas and private fields cannot be imported',
    () {
      for (final data in [
        {...task(), 'dueAt': '2026-02-30T10:00:00Z'},
        {...task(), 'idToken': 'secret'},
      ]) {
        expect(
          () => SyncRecord(kind: SyncKind.task, id: 't', data: data),
          throwsA(isA<AccountFailure>()),
        );
      }
      final r = SyncRecord(kind: SyncKind.task, id: 't', data: task());
      expect(
        () => SyncRecord.fromJson({...r.toJson(), 'schema': 2}),
        throwsA(isA<AccountFailure>()),
      );
    },
  );
  test('overlapping enabled segments are rejected while disabled history can overlap', () {
    Map<String, dynamic> segment(String id, bool enabled) => RecurrenceRule(
      id: id,
      taskId: 't',
      spec: const RepeatSpec(
        frequency: RepeatFrequency.daily,
        firstDate: '2026-01-05',
        zone: 'UTC',
      ),
      template: TaskDraft(title: 'Lặp', dueAt: DateTime.utc(2026, 1, 5, 10)),
      templateDate: '2026-01-05',
      enabled: enabled,
    ).toJson()..remove('revision');
    expect(
      () => SyncRecord(
        kind: SyncKind.recurrence,
        id: 't',
        data: {
          'taskId': 't',
          'rules': [segment('a', true), segment('b', true)],
        },
      ),
      throwsA(isA<AccountFailure>()),
    );
    final valid = SyncRecord(
      kind: SyncKind.recurrence,
      id: 't',
      data: {
        'taskId': 't',
        'rules': [segment('a', true), segment('b', false)],
      },
    );
    expect((valid.data['rules'] as List).length, 2);
  });
}
