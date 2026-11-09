import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../domain/sync_record.dart';
import 'workspace_records.dart';

/// An explicit copy uses new IDs, preserving existing account and local work.
/// No preferences, reminder history, credentials or character files are copied.
Future<void> copyWorkspace(
  List<SyncRecord> source,
  WorkspaceRecords target,
) async {
  final current = await target.read();
  final ids = <String, String>{};
  for (final record in source) {
    if (record.kind == SyncKind.category) {
      final same = current.values
          .where(
            (r) =>
                r.kind == SyncKind.category &&
                r.contentHash == record.contentHash,
          )
          .firstOrNull;
      ids[record.id] = same?.id ?? const Uuid().v4();
    } else if (record.kind == SyncKind.task) {
      ids[record.id] = const Uuid().v4();
    } else if (record.kind == SyncKind.recurrence) {
      for (final raw in record.data['rules'] as List) {
        ids[(raw as Map)['id'] as String] = const Uuid().v4();
      }
    }
  }
  for (final record in source.where((r) => r.kind == SyncKind.occurrence)) {
    ids[record.id] = sha256
        .convert(
          utf8.encode('${ids[record.data['taskId']]}|${record.data['date']}'),
        )
        .toString();
  }
  Map<String, dynamic> draft(Map<String, dynamic> j) => {
    ...j,
    if (j['categoryId'] != null) 'categoryId': ids[j['categoryId']]!,
  };
  await target.db.transaction(() async {
    final sorted = [...source]
      ..sort((a, b) => _order(a.kind).compareTo(_order(b.kind)));
    for (final r in sorted) {
      final data = switch (r.kind) {
        SyncKind.category => r.data,
        SyncKind.task => draft(r.data),
        SyncKind.recurrence => {
          'taskId': ids[r.id]!,
          'rules': [
            for (final raw in r.data['rules'] as List)
              {
                ...(raw as Map).cast<String, dynamic>(),
                'id': ids[raw['id']]!,
                'taskId': ids[r.id]!,
                'template': draft((raw['template'] as Map).cast()),
              },
          ],
        },
        SyncKind.occurrence => {
          ...r.data,
          'taskId': ids[r.data['taskId']]!,
          'ruleId': ids[r.data['ruleId']]!,
          'overrides': {
            ...(r.data['overrides'] as Map).cast<String, dynamic>(),
            if ((r.data['overrides'] as Map)['categoryId'] != null)
              'categoryId': ids[(r.data['overrides'] as Map)['categoryId']]!,
          },
          if (r.data['draft'] != null)
            'draft': draft((r.data['draft'] as Map).cast()),
        },
        SyncKind.reminderConfig => {
          ...r.data,
          'taskId': ids[r.data['taskId']]!,
          'rules': [
            for (final raw in r.data['rules'] as List)
              {
                ...(raw as Map).cast<String, dynamic>(),
                'id': const Uuid().v4(),
                'taskId': ids[r.id]!,
                if (raw['occurrenceId'] != null)
                  'occurrenceId': ids[raw['occurrenceId']]!,
              },
          ],
        },
      };
      await target.apply(
        SyncRecord(
          kind: r.kind,
          id: ids[r.id]!,
          data: data,
          deleted: r.deleted,
        ),
      );
    }
    await target.materialize();
    await target.read();
  });
}

int _order(SyncKind kind) => switch (kind) {
  SyncKind.category => 0,
  SyncKind.task => 1,
  SyncKind.recurrence => 2,
  SyncKind.occurrence => 3,
  SyncKind.reminderConfig => 4,
};
