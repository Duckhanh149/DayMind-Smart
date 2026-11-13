import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/account.dart';
import '../domain/sync_record.dart';
import 'firebase_rest.dart';

class FirestoreRestGateway implements SyncGateway {
  FirestoreRestGateway(this.endpoints, this.http);
  final FirebaseEndpoints endpoints;
  final JsonTransport http;
  String _path(AuthSession s, String suffix) {
    endpoints.validateSessionProject(s);
    return '/users/${s.uid}$suffix';
  }

  String _name(AuthSession s, String suffix) =>
      '${endpoints.documentPrefix}${_path(s, suffix)}';
  Future<Map<String, dynamic>?> _get(AuthSession s, String suffix) =>
      http.request(
        'GET',
        endpoints.firestore(_path(s, suffix)),
        token: s.idToken,
        missingIsNull: true,
      );
  Future<String> _commit(
    AuthSession s,
    String suffix,
    Map<String, dynamic> fields, {
    String? expectedVersion,
  }) async {
    final response = (await http.request(
      'POST',
      endpoints.firestore(':commit'),
      token: s.idToken,
      body: {
        'writes': [
          {
            'update': {'name': _name(s, suffix), 'fields': fields},
            'currentDocument': expectedVersion == null
                ? {'exists': false}
                : {'updateTime': expectedVersion},
          },
        ],
      },
    ))!;
    final results = response['writeResults'] as List;
    return (results.single as Map)['updateTime'] as String;
  }

  Map<String, dynamic> _status(bool active) => {
    'schema': {'integerValue': '1'},
    'active': {'booleanValue': active},
  };
  @override
  Future<bool> active(AuthSession session) async {
    final doc = await _get(session, '');
    if (doc == null) return false;
    final f = doc['fields'] as Map?;
    if ((f?['schema'] as Map?)?['integerValue'] != '1' ||
        (f?['active'] as Map?)?['booleanValue'] is! bool) {
      throw const AccountFailure(
        'invalid_account',
        'Trạng thái tài khoản không hợp lệ. Không ghi đè dữ liệu cục bộ.',
      );
    }
    return (f!['active'] as Map)['booleanValue'] == true;
  }

  @override
  Future<void> provision(AuthSession session) async {
    final doc = await _get(session, '');
    if (doc != null) {
      if (!await active(session)) {
        throw const AccountFailure(
          'account_deleted',
          'Tài khoản này đã được đánh dấu xóa; không đồng bộ lại dữ liệu cũ.',
        );
      }
      return;
    }
    try {
      await _commit(session, '', _status(true));
    } on AccountFailure catch (e) {
      if (!['ALREADY_EXISTS', 'FAILED_PRECONDITION'].contains(e.code)) rethrow;
      if (!await active(session)) {
        throw const AccountFailure(
          'account_deleted',
          'Tài khoản này đã được đánh dấu xóa.',
        );
      }
    }
  }

  Map<String, dynamic> _fields(SyncRecord r) => {
    'schema': {'integerValue': '1'},
    'kind': {'stringValue': r.kind.name},
    'recordId': {'stringValue': r.id},
    'payload': {'stringValue': _encodedPayload(r)},
    'deleted': {'booleanValue': r.deleted},
  };
  String _encodedPayload(SyncRecord record) {
    final raw = canonicalJson(record.data), bytes = utf8.encode(raw);
    final payload = bytes.length > 32768
        ? 'z1:${base64Encode(ZLibEncoder(level: 6).convert(bytes))}'
        : raw;
    if (utf8.encode(payload).length > 128 * 1024) {
      throw const AccountFailure(
        'record_limit',
        'Bản ghi quá lớn để đồng bộ an toàn. Nội dung vẫn được giữ trên thiết bị.',
      );
    }
    return payload;
  }

  Future<String> _decodedPayload(String raw) async {
    if (utf8.encode(raw).length > 128 * 1024) {
      throw const AccountFailure(
        'record_limit',
        'Bản ghi vượt giới hạn đồng bộ an toàn.',
      );
    }
    if (!raw.startsWith('z1:')) return raw;
    final input = base64Decode(raw.substring(3));
    Stream<List<int>> chunks() async* {
      for (var i = 0; i < input.length; i += 1024) {
        yield Uint8List.sublistView(
          input,
          i,
          (i + 1024).clamp(0, input.length),
        );
      }
    }

    final result = BytesBuilder(copy: false);
    var count = 0;
    await for (final chunk in chunks().transform(ZLibDecoder())) {
      count += chunk.length;
      if (count > 4 * 1024 * 1024) {
        throw const AccountFailure(
          'record_limit',
          'Bản ghi sau giải mã vượt giới hạn an toàn.',
        );
      }
      result.add(chunk);
    }
    return utf8.decode(result.takeBytes());
  }

  Future<RemoteRecord> _decode(Map<String, dynamic> doc) async {
    try {
      final f = doc['fields'] as Map<String, dynamic>;
      final raw = (f['payload'] as Map)['stringValue'] as String;
      if (utf8.encode(raw).length > 128 * 1024) {
        throw const AccountFailure(
          'record_limit',
          'Bản ghi vượt giới hạn đồng bộ an toàn.',
        );
      }
      final r = SyncRecord.fromJson({
        'schema': int.parse((f['schema'] as Map)['integerValue'] as String),
        'kind': (f['kind'] as Map)['stringValue'],
        'id': (f['recordId'] as Map)['stringValue'],
        'data': jsonDecode(await _decodedPayload(raw)),
        'deleted': (f['deleted'] as Map)['booleanValue'],
      });
      if ((doc['name'] as String).split('/').last != r.key) {
        throw const AccountFailure(
          'invalid_record',
          'Mã bản ghi không khớp nội dung.',
        );
      }
      return RemoteRecord(r, doc['updateTime'] as String);
    } on AccountFailure {
      rethrow;
    } catch (_) {
      throw const AccountFailure(
        'invalid_record',
        'Dữ liệu máy chủ không hợp lệ. Bản trên thiết bị được giữ nguyên.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _list(
    AuthSession s,
    String collection, {
    bool metadataOnly = false,
  }) async {
    final result = <Map<String, dynamic>>[];
    String? page;
    var bytes = 0;
    do {
      final response = (await http.request(
        'GET',
        endpoints.firestore(
          _path(s, '/$collection'),
          query: {
            'pageSize': '50',
            'pageToken': ?page,
            if (metadataOnly) 'mask.fieldPaths': 'schema',
          },
        ),
        token: s.idToken,
      ))!;
      for (final doc in (response['documents'] as List? ?? [])) {
        final row = (doc as Map).cast<String, dynamic>();
        if (!(row['name'] as String).startsWith(
          '${_name(s, '/$collection')}/',
        )) {
          throw const AccountFailure(
            'owner_mismatch',
            'Bản dữ liệu không thuộc tài khoản này.',
          );
        }
        bytes += utf8.encode(jsonEncode(row)).length;
        result.add(row);
        if (result.length > 10000 || bytes > 16 * 1024 * 1024) {
          throw const AccountFailure(
            'response_limit',
            'Kho dữ liệu vượt giới hạn đồng bộ an toàn trên thiết bị.',
          );
        }
      }
      page = response['nextPageToken'] as String?;
    } while (page != null && page.isNotEmpty);
    return result;
  }

  @override
  Future<List<RemoteRecord>> fetchAll(AuthSession session) async {
    final records = <RemoteRecord>[];
    var bytes = 0;
    for (final doc in await _list(session, 'records')) {
      final row = await _decode(doc);
      bytes += utf8.encode(canonicalJson(row.record.data)).length;
      if (bytes > 16 * 1024 * 1024) {
        throw const AccountFailure(
          'response_limit',
          'Kho dữ liệu vượt giới hạn đồng bộ an toàn trên thiết bị.',
        );
      }
      records.add(row);
    }
    return records;
  }

  @override
  Future<RemoteRecord?> fetch(AuthSession session, String key) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(key)) {
      throw const AccountFailure('invalid_record', 'Mã bản ghi không hợp lệ.');
    }
    final doc = await _get(session, '/records/$key');
    return doc == null ? null : _decode(doc);
  }

  @override
  Future<String> write(
    AuthSession session,
    SyncRecord record, {
    String? expectedVersion,
  }) => _commit(
    session,
    '/records/${record.key}',
    _fields(record),
    expectedVersion: expectedVersion,
  );
  @override
  Future<PrimaryDevice?> primary(AuthSession session) async {
    final doc = await _get(session, '/settings/primary');
    if (doc == null) return null;
    final id =
        ((doc['fields'] as Map)['deviceId'] as Map)['stringValue'] as String;
    validRecordId(id);
    return PrimaryDevice(id, doc['updateTime'] as String);
  }

  @override
  Future<PrimaryDevice> claimPrimary(
    AuthSession session,
    String deviceId, {
    String? expectedVersion,
  }) async {
    validRecordId(deviceId);
    final version = await _commit(session, '/settings/primary', {
      'schema': {'integerValue': '1'},
      'deviceId': {'stringValue': deviceId},
    }, expectedVersion: expectedVersion);
    return PrimaryDevice(deviceId, version);
  }

  @override
  Future<void> registerDevice(
    AuthSession session,
    String deviceId,
    String name,
  ) async {
    validRecordId(deviceId);
    if (name.trim().isEmpty || name.length > 80) {
      throw const AccountFailure(
        'invalid_device',
        'Tên thiết bị cần từ 1 đến 80 ký tự.',
      );
    }
    final old = await _get(session, '/devices/$deviceId');
    await _commit(session, '/devices/$deviceId', {
      'schema': {'integerValue': '1'},
      'name': {'stringValue': name.trim()},
    }, expectedVersion: old?['updateTime'] as String?);
  }

  @override
  Future<Map<String, String>> devices(AuthSession session) async => {
    for (final doc in await _list(session, 'devices'))
      (doc['name'] as String).split('/').last:
          ((doc['fields'] as Map)['name'] as Map)['stringValue'] as String,
  };
  @override
  Future<void> deleteData(AuthSession session) async {
    final status = await _get(session, '');
    if (status == null) {
      await _commit(session, '', _status(false));
    } else if (await active(session)) {
      await _commit(
        session,
        '',
        _status(false),
        expectedVersion: status['updateTime'] as String,
      );
    }
    for (final collection in ['records', 'settings', 'devices']) {
      final docs = await _list(session, collection, metadataOnly: true);
      for (var i = 0; i < docs.length; i += 200) {
        await http.request(
          'POST',
          endpoints.firestore(':commit'),
          token: session.idToken,
          body: {
            'writes': docs
                .skip(i)
                .take(200)
                .map((d) => {'delete': d['name']})
                .toList(),
          },
        );
      }
    }
  }
}
