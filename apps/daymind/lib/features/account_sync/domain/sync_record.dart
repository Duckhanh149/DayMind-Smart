import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../tasks/domain/task.dart';
import '../../recurrence/domain/recurrence.dart';
import '../../reminders/domain/reminder.dart';
import '../../companion/domain/companion.dart';
import 'account.dart';

enum SyncKind {
  task,
  category,
  recurrence,
  occurrence,
  reminderConfig,
  companionProfile,
}

Object? canonicalValue(Object? value) {
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort();
    return {for (final key in keys) key: canonicalValue(value[key])};
  }
  if (value is List) return value.map(canonicalValue).toList();
  return value;
}

String canonicalJson(Object? value) => jsonEncode(canonicalValue(value));
void validRecordId(Object? value) {
  if (value is! String ||
      !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.:-]{0,159}$').hasMatch(value)) {
    throw const AccountFailure(
      'invalid_record',
      'Mã dữ liệu đồng bộ không hợp lệ.',
    );
  }
}

DateTime? validInstant(Object? value, {bool required = false}) {
  if (value == null && !required) return null;
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$')
          .hasMatch(value)) {
    throw const AccountFailure(
      'invalid_record',
      'Thời điểm đồng bộ cần có múi giờ UTC rõ ràng.',
    );
  }
  final parsed = DateTime.parse(value);
  if (parsed.year < 2000 ||
      parsed.year > 2100 ||
      dateKey(parsed) != value.substring(0, 10) ||
      parsed.hour != int.parse(value.substring(11, 13)) ||
      parsed.minute != int.parse(value.substring(14, 16)) ||
      parsed.second != int.parse(value.substring(17, 19))) {
    throw const AccountFailure(
      'invalid_record',
      'Thời điểm đồng bộ không hợp lệ.',
    );
  }
  return parsed;
}

const _draftFields = {
  'title',
  'description',
  'priority',
  'status',
  'categoryId',
  'dueAt',
  'scheduledStartAt',
  'scheduledEndAt',
};
const _overrideFields = {
  'title',
  'description',
  'priority',
  'categoryId',
  'dueAt',
  'scheduledStartAt',
  'scheduledEndAt',
};
void _keys(Map<String, dynamic> data, Set<String> allowed) {
  if (data.keys.any((k) => !allowed.contains(k))) {
    throw const AccountFailure(
      'invalid_record',
      'Định dạng bản ghi có trường không được hỗ trợ.',
    );
  }
}

void _draft(Map<String, dynamic> data) {
  _keys(data, _draftFields);
  TaskDraft.fromJson(data).validate();
  if ((data['title'] as String).length > 240) {
    throw const ValidationException('Tên công việc quá dài.');
  }
  for (final key in ['dueAt', 'scheduledStartAt', 'scheduledEndAt']) {
    validInstant(data[key]);
  }
  if (data['categoryId'] != null) validRecordId(data['categoryId']);
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const AccountFailure(
      'invalid_record',
      'Định dạng bản ghi không hợp lệ.',
    );
  }
  return value;
}

Object? _frozenJson(Object? value, [int depth = 0]) {
  if (depth > 12) {
    throw const AccountFailure('invalid_record', 'Dữ liệu lồng quá sâu.');
  }
  if (value is Map<String, dynamic>) {
    if (value.length > 64) {
      throw const AccountFailure(
        'invalid_record',
        'Bản ghi có quá nhiều trường.',
      );
    }
    return Map<String, dynamic>.unmodifiable(
      value.map((k, v) => MapEntry(k, _frozenJson(v, depth + 1))),
    );
  }
  if (value is List) {
    if (value.length > 256) {
      throw const AccountFailure(
        'invalid_record',
        'Danh sách trong bản ghi quá lớn.',
      );
    }
    return List<dynamic>.unmodifiable(
      value.map((v) => _frozenJson(v, depth + 1)),
    );
  }
  if (value == null || value is bool || value is int || value is String) {
    return value;
  }
  throw const AccountFailure(
    'invalid_record',
    'Kiểu dữ liệu đồng bộ không hợp lệ.',
  );
}

/// `deleted` removes a sync entity/override. Task soft deletion uses data.deletedAt;
/// an explicit skipped/deleted occurrence uses data.deleted, preserving its date.
class SyncRecord {
  factory SyncRecord({
    required SyncKind kind,
    required String id,
    required Map<String, dynamic> data,
    bool deleted = false,
  }) {
    final frozen = _frozenJson(data) as Map<String, dynamic>;
    final record = SyncRecord._(kind, id, frozen, deleted);
    record.validate();
    return SyncRecord._(
      kind,
      id,
      _frozenJson(record._normalized()) as Map<String, dynamic>,
      deleted,
    );
  }
  const SyncRecord._(this.kind, this.id, this.data, this.deleted);
  Map<String, dynamic> _normalized() {
    if (deleted) return data;
    switch (kind) {
      case SyncKind.task:
        return {
          ...TaskDraft.fromJson(data).toJson(),
          'createdAt': validInstant(
            data['createdAt'],
            required: true,
          )!.toIso8601String(),
          'updatedAt': validInstant(
            data['updatedAt'],
            required: true,
          )!.toIso8601String(),
          'completedAt': validInstant(data['completedAt'])?.toIso8601String(),
          'deletedAt': validInstant(data['deletedAt'])?.toIso8601String(),
        };
      case SyncKind.recurrence:
        final rules =
            (data['rules'] as List)
                .map(
                  (j) => RecurrenceRule.fromJson(
                    (j as Map).cast<String, dynamic>(),
                  ).toJson()..remove('revision'),
                )
                .toList()
              ..sort(
                (a, b) => (a['id'] as String).compareTo(b['id'] as String),
              );
        return {'taskId': id, 'rules': rules};
      case SyncKind.reminderConfig:
        final rules =
            (data['rules'] as List)
                .map(
                  (j) =>
                      ReminderRule.fromJson((j as Map).cast<String, dynamic>())
                          .toJson()
                        ..remove('revision'),
                )
                .toList()
              ..sort(
                (a, b) => (a['id'] as String).compareTo(b['id'] as String),
              );
        return {'taskId': data['taskId'], 'mode': data['mode'], 'rules': rules};
      case SyncKind.occurrence:
        return {
          ...data,
          'completedAt': validInstant(data['completedAt'])?.toIso8601String(),
          'detached': data['detached'] ?? false,
          if (data['draft'] != null)
            'draft': TaskDraft.fromJson(_map(data['draft'])).toJson(),
        };
      case SyncKind.category:
        return data;
      case SyncKind.companionProfile:
        return CompanionProfile.fromJson(data).toJson();
    }
  }

  final SyncKind kind;
  final String id;
  final Map<String, dynamic> data;
  final bool deleted;
  String get key => sha256.convert(utf8.encode('${kind.name}|$id')).toString();
  String get contentHash =>
      sha256.convert(utf8.encode(canonicalJson(toJson()))).toString();
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'kind': kind.name,
    'id': id,
    'data': data,
    'deleted': deleted,
  };
  factory SyncRecord.fromJson(Map<String, dynamic> j) {
    try {
      _keys(j, {'schema', 'kind', 'id', 'data', 'deleted'});
      if (j['deleted'] is! bool) {
        throw const AccountFailure(
          'invalid_record',
          'Trạng thái bản ghi không hợp lệ.',
        );
      }
      if (j['schema'] != 1) {
        throw const AccountFailure(
          'unsupported_schema',
          'Bản dữ liệu dùng định dạng mới hơn. Nội dung trên thiết bị vẫn được giữ.',
        );
      }
      return SyncRecord(
        kind: SyncKind.values.byName(j['kind'] as String),
        id: j['id'] as String,
        data: _map(j['data']),
        deleted: j['deleted'] == true,
      );
    } on AccountFailure {
      rethrow;
    } catch (_) {
      throw const AccountFailure(
        'invalid_record',
        'Bản dữ liệu không hợp lệ; không ghi đè dữ liệu trên thiết bị.',
      );
    }
  }
  void validate() {
    try {
      validRecordId(id);
      if (utf8.encode(canonicalJson(data)).length >
          (kind == SyncKind.recurrence ? 4 * 1024 * 1024 : 128 * 1024)) {
        throw const AccountFailure(
          'record_limit',
          'Bản ghi vượt giới hạn đồng bộ an toàn.',
        );
      }
      if (deleted) {
        if (kind == SyncKind.task ||
            kind == SyncKind.category ||
            kind == SyncKind.recurrence ||
            kind == SyncKind.companionProfile) {
          throw const AccountFailure(
            'invalid_record',
            'Công việc và chuỗi dùng xóa mềm để giữ lịch sử.',
          );
        }
        if (kind == SyncKind.occurrence) {
          _keys(data, {'taskId', 'ruleId', 'date'});
          validRecordId(data['taskId']);
          validRecordId(data['ruleId']);
          civilDate(data['date'] as String);
          if (id !=
              sha256
                  .convert(utf8.encode('${data['taskId']}|${data['date']}'))
                  .toString()) {
            throw const ValidationException(
              'Mã lần lặp không khớp ngày và chuỗi.',
            );
          }
        } else {
          _keys(data, {'taskId'});
          validRecordId(data['taskId']);
        }
        return;
      }
      switch (kind) {
        case SyncKind.task:
          _validateTask();
        case SyncKind.category:
          _validateCategory();
        case SyncKind.recurrence:
          _validateRecurrence();
        case SyncKind.occurrence:
          _validateOccurrence();
        case SyncKind.reminderConfig:
          _validateReminderConfig();
        case SyncKind.companionProfile:
          if (id != 'primary') {
            throw const AccountFailure(
              'invalid_record',
              'Mã hồ sơ Companion không hợp lệ.',
            );
          }
          CompanionProfile.fromJson(data);
      }
    } on AccountFailure {
      rethrow;
    } catch (_) {
      throw const AccountFailure(
        'invalid_record',
        'Bản dữ liệu không hợp lệ; không ghi đè dữ liệu trên thiết bị.',
      );
    }
  }

  void _validateTask() {
    _keys(data, {
      ..._draftFields,
      'createdAt',
      'updatedAt',
      'completedAt',
      'deletedAt',
    });
    _draft({
      for (final key in _draftFields)
        if (data.containsKey(key)) key: data[key],
    });
    validInstant(data['createdAt'], required: true);
    validInstant(data['updatedAt'], required: true);
    validInstant(data['completedAt']);
    validInstant(data['deletedAt']);
  }

  void _validateCategory() {
    _keys(data, {'name', 'color'});
    if (data['name'] is! String ||
        (data['name'] as String).trim().isEmpty ||
        (data['name'] as String).length > 40 ||
        data['color'] is! int ||
        (data['color'] as int) < 0 ||
        (data['color'] as int) > 0xffffffff) {
      throw const ValidationException('Danh mục đồng bộ không hợp lệ.');
    }
  }

  void _validateRecurrence() {
    _keys(data, {'taskId', 'rules'});
    validRecordId(data['taskId']);
    if (data['taskId'] != id ||
        data['rules'] is! List ||
        (data['rules'] as List).isEmpty ||
        (data['rules'] as List).length > 128) {
      throw const ValidationException('Chuỗi đồng bộ không hợp lệ.');
    }
    final ids = <String>{};
    final ranges = <(String, String)>[];
    for (final raw in data['rules'] as List) {
      final j = _map(raw);
      _keys(j, {
        'id',
        'taskId',
        'spec',
        'template',
        'templateDate',
        'activeFrom',
        'cutoff',
        'enabled',
      });
      validRecordId(j['id']);
      if (!ids.add(j['id'] as String) || j['taskId'] != id) {
        throw const ValidationException(
          'Chuỗi có phiên bản trùng hoặc không thuộc công việc này.',
        );
      }
      _keys(_map(j['spec']), {
        'frequency',
        'firstDate',
        'zone',
        'minute',
        'interval',
        'weekdays',
        'monthPolicy',
        'until',
        'count',
      });
      _draft(_map(j['template']));
      final r = RecurrenceRule.fromJson(j);
      r.spec.validate();
      final weekdays = _map(j['spec'])['weekdays'];
      if (weekdays != null &&
          (weekdays is! List ||
              weekdays.length > 7 ||
              weekdays.toSet().length != weekdays.length)) {
        throw const ValidationException('Ngày trong tuần không hợp lệ.');
      }
      civilDate(r.templateDate);
      if (r.activeFrom != null) civilDate(r.activeFrom!);
      if (r.cutoff != null) civilDate(r.cutoff!);
      if (j['enabled'] is! bool) {
        throw const ValidationException('Trạng thái chuỗi không hợp lệ.');
      }
      if (r.enabled) {
        final start =
            r.activeFrom == null ||
                r.spec.firstDate.compareTo(r.activeFrom!) > 0
            ? r.spec.firstDate
            : r.activeFrom!;
        final limits = [
          if (r.cutoff != null) r.cutoff!,
          if (r.spec.until != null) r.spec.until!,
        ]..sort();
        final end = limits.firstOrNull ?? '2100-12-31';
        if (start.compareTo(end) <= 0) ranges.add((start, end));
      }
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    for (var i = 1; i < ranges.length; i++) {
      if (ranges[i].$1.compareTo(ranges[i - 1].$2) <= 0) {
        throw const ValidationException(
          'Các đoạn lịch trong chuỗi đang chồng nhau.',
        );
      }
    }
  }

  void _validateOccurrence() {
    _keys(data, {
      'taskId',
      'ruleId',
      'date',
      'status',
      'overrides',
      'deleted',
      'completedAt',
      'draft',
      'detached',
    });
    validRecordId(data['taskId']);
    validRecordId(data['ruleId']);
    civilDate(data['date'] as String);
    final expected = sha256
        .convert(utf8.encode('${data['taskId']}|${data['date']}'))
        .toString();
    if (id != expected ||
        ![
          'todo',
          'inProgress',
          'completed',
          'cancelled',
          'skipped',
        ].contains(data['status']) ||
        data['deleted'] is! bool) {
      throw const ValidationException('Lần lặp đồng bộ không hợp lệ.');
    }
    if (data['detached'] != null && data['detached'] is! bool) {
      throw const ValidationException('Trạng thái ngoại lệ không hợp lệ.');
    }
    final overrides = _map(data['overrides']);
    _keys(overrides, _overrideFields);
    _draft({
      ...const TaskDraft(title: 'Kiểm tra ngoại lệ').toJson(),
      ...overrides,
    });
    validInstant(data['completedAt']);
    if (['completed', 'cancelled', 'skipped'].contains(data['status']) ||
        data['detached'] == true) {
      _draft(_map(data['draft']));
      if (data['status'] != 'skipped' &&
          TaskDraft.fromJson(_map(data['draft'])).status.name !=
              data['status']) {
        throw const ValidationException(
          'Trạng thái lịch sử không khớp nội dung lần lặp.',
        );
      }
    } else if (data['draft'] != null) {
      throw const ValidationException(
        'Lần chưa hoàn thành dùng mẫu chuỗi và ngoại lệ.',
      );
    }
  }

  void _validateReminderConfig() {
    _keys(data, {'taskId', 'mode', 'rules'});
    validRecordId(data['taskId']);
    if (!['auto', 'off', 'custom'].contains(data['mode']) ||
        data['rules'] is! List ||
        (data['rules'] as List).length > 8) {
      throw const ValidationException('Cấu hình nhắc không hợp lệ.');
    }
    final ids = <String>{};
    for (final raw in data['rules'] as List) {
      final j = _map(raw);
      _keys(j, {
        'id',
        'taskId',
        'kind',
        'offsetMinutes',
        'absoluteAt',
        'enabled',
        'occurrenceId',
      });
      final r = ReminderRule.fromJson(j);
      validRecordId(r.id);
      validRecordId(r.taskId);
      if (r.taskId != id ||
          !ids.add(r.id) ||
          j['enabled'] is! bool ||
          j['offsetMinutes'] is! int ||
          r.offsetMinutes < 0 ||
          r.offsetMinutes > 43200 ||
          r.kind == ReminderKind.absolute && r.absoluteAt == null ||
          r.id == 'default' ||
          r.id.startsWith('snooze:')) {
        throw const ValidationException('Mốc nhắc không hợp lệ.');
      }
      validInstant(j['absoluteAt']);
      if (r.occurrenceId != null) validRecordId(r.occurrenceId);
    }
  }
}

class RemoteRecord {
  const RemoteRecord(this.record, this.version);
  final SyncRecord record;
  final String
  version; // Opaque Firestore updateTime; retain nanoseconds exactly.
}

class PrimaryDevice {
  const PrimaryDevice(this.id, this.version);
  final String id, version;
}

abstract interface class SyncGateway {
  Future<void> provision(AuthSession session);
  Future<bool> active(AuthSession session);
  Future<List<RemoteRecord>> fetchAll(AuthSession session);
  Future<RemoteRecord?> fetch(AuthSession session, String key);
  Future<String> write(
    AuthSession session,
    SyncRecord record, {
    String? expectedVersion,
  });
  Future<PrimaryDevice?> primary(AuthSession session);
  Future<PrimaryDevice> claimPrimary(
    AuthSession session,
    String deviceId, {
    String? expectedVersion,
  });
  Future<void> registerDevice(
    AuthSession session,
    String deviceId,
    String name,
  );
  Future<Map<String, String>> devices(AuthSession session);
  Future<void> deleteData(AuthSession session);
}
