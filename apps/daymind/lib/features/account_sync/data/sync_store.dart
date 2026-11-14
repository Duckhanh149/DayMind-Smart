import 'package:uuid/uuid.dart';

import '../../../core/record_store.dart';
import '../../tasks/data/database.dart';
import '../domain/account.dart';
import '../domain/sync_record.dart';
import 'workspace_records.dart';

class PendingMutation {
  const PendingMutation(this.id, this.record, {this.seed = false});
  final String id;
  final SyncRecord record;
  final bool seed;
  factory PendingMutation.fromJson(Map<String, dynamic> j) => PendingMutation(
    j['mutationId'] as String,
    SyncRecord.fromJson((j['record'] as Map).cast()),
    seed: j['seed'] == true,
  );
}

class ConflictHeader {
  const ConflictHeader(
    this.id,
    this.key,
    this.kind,
    this.parentId,
    this.label,
    this.status,
    this.localHash,
    this.remoteVersion,
  );
  final String id, key, label, status, localHash;
  final String? parentId, remoteVersion;
  final SyncKind kind;
  factory ConflictHeader.fromJson(Map<String, dynamic> j) => ConflictHeader(
    j['id'] as String,
    j['key'] as String,
    SyncKind.values.byName(j['kind'] as String),
    j['parentId'] as String?,
    j['label'] as String,
    j['status'] as String,
    j['localHash'] as String,
    j['remoteVersion'] as String?,
  );
}

class SyncConflict {
  const SyncConflict(this.header, this.local, this.remote);
  final ConflictHeader header;
  final SyncRecord local;
  final RemoteRecord? remote;
}

class SyncStore {
  SyncStore(this.repository, this.owner, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now,
      records = RecordStore(repository.db),
      workspace = WorkspaceRecords(repository, clock: clock);
  final SqliteTaskRepository repository;
  final RecordStore records;
  final WorkspaceRecords workspace;
  final String owner;
  final DateTime Function() clock;
  DaymindDatabase get db => repository.db;
  Future<void> bindOwner() async {
    final stored = await records.get('account', 'session');
    if (stored != null && stored['ownerId'] != owner) {
      throw const AccountFailure(
        'owner_mismatch',
        'Không mở dữ liệu của tài khoản khác.',
      );
    }
    await records.put('account', 'session', {'ownerId': owner});
  }

  static int order(SyncKind kind) => switch (kind) {
    SyncKind.category => 0,
    SyncKind.task => 1,
    SyncKind.recurrence => 2,
    SyncKind.occurrence => 3,
    SyncKind.reminderConfig => 4,
    SyncKind.companionProfile => 5,
  };
  static String? parentOf(SyncRecord r) => switch (r.kind) {
    SyncKind.category || SyncKind.companionProfile => null,
    SyncKind.task || SyncKind.recurrence => r.id,
    _ => r.data['taskId'] as String,
  };
  bool _seed(SyncRecord r) {
    if (r.kind != SyncKind.category) return false;
    final values = {
      'work': ('Công việc', 0xffb97156),
      'personal': ('Cá nhân', 0xff6b8b72),
      'learning': ('Học tập', 0xff8a7cb2),
    };
    final expected = values[r.id];
    return expected != null &&
        r.data['name'] == expected.$1 &&
        r.data['color'] == expected.$2;
  }

  SyncRecord _missing(SyncRecord old) {
    if (old.kind == SyncKind.occurrence) {
      return SyncRecord(
        kind: old.kind,
        id: old.id,
        deleted: true,
        data: {
          'taskId': old.data['taskId'],
          'ruleId': old.data['ruleId'],
          'date': old.data['date'],
        },
      );
    }
    if (old.kind == SyncKind.reminderConfig) {
      return SyncRecord(
        kind: old.kind,
        id: old.id,
        deleted: true,
        data: {'taskId': old.data['taskId']},
      );
    }
    throw const AccountFailure(
      'missing_local',
      'Thiết bị thiếu một phần dữ liệu đã lưu. Chưa xóa hoặc ghi đè bản máy chủ.',
    );
  }

  Future<void> _enqueue(SyncRecord record, {bool seed = false}) =>
      records.put('sync_outbox', record.key, {
        'id': record.key,
        'mutationId': const Uuid().v4(),
        'record': record.toJson(),
        'seed': seed,
        'queuedAt': clock().toUtc().toIso8601String(),
      });
  Future<int> capture() => db.transaction(() async {
    final snapshot = await workspace.read();
    final meta = {
      for (final j in await records.list('sync_meta')) j['id'] as String: j,
    };
    final queued = {
      for (final j in await records.list('sync_outbox'))
        j['id'] as String: PendingMutation.fromJson(j),
    };
    var changed = 0;
    for (final key in {...snapshot.keys, ...meta.keys, ...queued.keys}) {
      final local =
          snapshot[key] ??
          _missing(
            queued[key]?.record ??
                SyncRecord.fromJson((meta[key]!['record'] as Map).cast()),
          );
      final prior = queued[key];
      final base = meta[key];
      if (prior != null
          ? prior.record.contentHash != local.contentHash
          : base == null || base['hash'] != local.contentHash) {
        await _enqueue(local, seed: base == null && _seed(local));
        changed++;
      }
    }
    // Native action IDs live in the table key; remove only captured keys, never a concurrent arrival.
    final actions = await (db.select(
      db.extensionRecords,
    )..where((e) => e.area.equals('native_actions'))).get();
    for (final event in actions) {
      await records.remove('native_actions', event.id);
    }
    return changed;
  });
  Future<List<PendingMutation>> pending() async =>
      (await records.list('sync_outbox')).map(PendingMutation.fromJson).toList()
        ..sort((a, b) {
          final kind = order(a.record.kind).compareTo(order(b.record.kind));
          return kind != 0 ? kind : a.record.id.compareTo(b.record.id);
        });
  Future<String?> version(String key) async =>
      (await records.get('sync_meta', key))?['version'] as String?;
  Future<List<ConflictHeader>> conflicts({bool history = false}) async =>
      (await records.list('sync_conflict_heads'))
          .map(ConflictHeader.fromJson)
          .where((h) => history || h.status == 'active')
          .toList();
  Future<SyncConflict?> conflict(String id) async {
    final head = await records.get('sync_conflict_heads', id),
        body = await records.get('sync_conflict_bodies', id);
    if (head == null || body == null) return null;
    final remote = body['remote'] as Map?;
    return SyncConflict(
      ConflictHeader.fromJson(head),
      SyncRecord.fromJson((body['local'] as Map).cast()),
      remote == null
          ? null
          : RemoteRecord(
              SyncRecord.fromJson((remote['record'] as Map).cast()),
              remote['version'] as String,
            ),
    );
  }

  Future<void> _remember(RemoteRecord remote) =>
      records.put('sync_meta', remote.record.key, {
        'id': remote.record.key,
        'version': remote.version,
        'hash': remote.record.contentHash,
        'record': remote.record.toJson(),
      });
  Future<void> acknowledge(PendingMutation sent, String version) =>
      db.transaction(() async {
        await _remember(RemoteRecord(sent.record, version));
        final latest = await records.get('sync_outbox', sent.record.key);
        if (latest?['mutationId'] == sent.id) {
          await records.remove('sync_outbox', sent.record.key);
        }
      });
  String _label(SyncRecord r) => switch (r.kind) {
    SyncKind.task => r.data['title'] as String? ?? 'Công việc',
    SyncKind.category => r.data['name'] as String? ?? 'Danh mục',
    SyncKind.recurrence => 'Lịch của chuỗi',
    SyncKind.occurrence => 'Lần thực hiện ${r.data['date']}',
    SyncKind.reminderConfig => 'Cấu hình nhắc việc',
    SyncKind.companionProfile => 'Hồ sơ ${r.data['name']}',
  };
  Future<void> _archive(
    SyncRecord local,
    RemoteRecord? remote, {
    String reason = 'diverged',
  }) async {
    final active = (await conflicts())
        .where((h) => h.key == local.key)
        .toList();
    if (active.any(
      (h) =>
          h.localHash == local.contentHash &&
          h.remoteVersion == remote?.version,
    )) {
      return;
    }
    for (final old in active) {
      final head = (await records.get('sync_conflict_heads', old.id))!;
      await records.put('sync_conflict_heads', old.id, {
        ...head,
        'status': 'superseded',
      });
    }
    final id = const Uuid().v4();
    await records.put('sync_conflict_heads', id, {
      'id': id,
      'key': local.key,
      'kind': local.kind.name,
      'parentId': parentOf(local),
      'label': _label(local),
      'status': 'active',
      'localHash': local.contentHash,
      'remoteVersion': remote?.version,
      'reason': reason,
      'createdAt': clock().toUtc().toIso8601String(),
    });
    await records.put('sync_conflict_bodies', id, {
      'id': id,
      'local': local.toJson(),
      'remote': remote == null
          ? null
          : {'record': remote.record.toJson(), 'version': remote.version},
    });
  }

  bool _blocked(SyncRecord record, List<ConflictHeader> active) {
    if (active.any((h) => h.key == record.key)) return true;
    if (record.kind == SyncKind.task ||
        record.kind == SyncKind.category ||
        record.kind == SyncKind.companionProfile) {
      return false;
    }
    final parent = parentOf(record);
    return active.any(
      (h) =>
          h.parentId == parent &&
          (h.kind == SyncKind.task || h.kind == SyncKind.recurrence),
    );
  }

  Future<bool> blocked(SyncRecord record) async =>
      _blocked(record, await conflicts());

  Future<void> pull(List<RemoteRecord> remote) => db.transaction(() async {
    final local = await workspace.read();
    final meta = {
      for (final j in await records.list('sync_meta')) j['id'] as String: j,
    };
    final pending = {
      for (final j in await records.list('sync_outbox'))
        j['id'] as String: PendingMutation.fromJson(j),
    };
    final sorted = [...remote]
      ..sort((a, b) => order(a.record.kind).compareTo(order(b.record.kind)));
    for (final incoming in sorted) {
      final key = incoming.record.key, base = meta[key], queued = pending[key];
      final current =
          local[key] ??
          (queued == null && base == null
              ? null
              : _missing(
                  queued?.record ??
                      SyncRecord.fromJson((base!['record'] as Map).cast()),
                ));
      final active = await conflicts();
      if (_blocked(incoming.record, active) &&
          !active.any((h) => h.key == key)) {
        continue;
      }
      if (current?.contentHash == incoming.record.contentHash) {
        await _remember(incoming);
        if (queued != null) await records.remove('sync_outbox', key);
        await _converged(key);
        continue;
      }
      final bootstrap =
          queued?.seed == true && current != null && _seed(current);
      final dirty =
          !bootstrap &&
          (queued != null ||
              current != null &&
                  (base == null || base['hash'] != current.contentHash));
      if (dirty) {
        if (base != null && incoming.record.contentHash == base['hash']) {
          await _remember(incoming);
          await _converged(key);
          continue;
        }
        if (queued == null && current != null) await _enqueue(current);
        if (current != null) await _archive(current, incoming);
        continue;
      }
      await workspace.apply(incoming.record);
      await _remember(incoming);
      if (queued != null) await records.remove('sync_outbox', key);
      await _converged(key);
    }
    // A missing cloud entity is never interpreted as permission to resurrect/delete silently.
    final present = remote.map((r) => r.record.key).toSet();
    for (final entry in meta.entries.where((e) => !present.contains(e.key))) {
      final current = local[entry.key];
      if (current != null) {
        await _archive(current, null, reason: 'remote_missing');
      }
    }
    await workspace.materialize();
    await workspace.read();
  });
  Future<void> _converged(String key) async {
    for (final h in (await conflicts()).where((h) => h.key == key)) {
      final head = (await records.get('sync_conflict_heads', h.id))!;
      await records.put('sync_conflict_heads', h.id, {
        ...head,
        'status': 'converged',
      });
    }
  }

  Future<void> failedWrite(PendingMutation sent, RemoteRecord? remote) =>
      db.transaction(() async {
        final snapshot = await workspace.read();
        final local = snapshot[sent.record.key] ?? _missing(sent.record);
        if (remote?.record.contentHash == sent.record.contentHash) {
          await acknowledge(sent, remote!.version);
          return;
        }
        if (remote != null && local.contentHash == remote.record.contentHash) {
          await _remember(remote);
          final queued = await records.get('sync_outbox', local.key);
          if (queued != null &&
              PendingMutation.fromJson(queued).record.contentHash ==
                  local.contentHash) {
            await records.remove('sync_outbox', local.key);
          }
          await _converged(local.key);
          return;
        }
        await _archive(local, remote);
      });
  Future<void> resolve(String id, {required bool keepLocal}) =>
      db.transaction(() async {
        final c = await conflict(id);
        if (c == null || c.header.status != 'active') {
          throw const AccountFailure(
            'conflict_changed',
            'Xung đột vừa thay đổi. Hãy mở lại để chọn bản mới nhất.',
          );
        }
        final snapshot = await workspace.read();
        final local = snapshot[c.local.key] ?? _missing(c.local);
        if (local.contentHash != c.header.localHash) {
          throw const AccountFailure(
            'conflict_changed',
            'Bản trên thiết bị vừa thay đổi. Nội dung mới vẫn được giữ; hãy mở lại xung đột.',
          );
        }
        if (keepLocal) {
          if (c.remote != null) {
            await _remember(c.remote!);
          } else {
            await records.remove('sync_meta', local.key);
          }
          await _enqueue(local);
        } else {
          if (c.remote == null) {
            throw const AccountFailure(
              'remote_missing',
              'Bản máy chủ không còn tồn tại. Bạn có thể giữ bản trên thiết bị hoặc xuất bản sao.',
            );
          }
          await workspace.apply(c.remote!.record);
          await _remember(c.remote!);
          await records.remove('sync_outbox', local.key);
          await workspace.materialize();
          await workspace.read();
        }
        final head = (await records.get('sync_conflict_heads', id))!;
        await records.put('sync_conflict_heads', id, {
          ...head,
          'status': keepLocal ? 'local' : 'remote',
        });
      });
}
