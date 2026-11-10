import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../account_sync/domain/sync_record.dart';
import '../../companion/domain/companion.dart';

class BackupFailure implements Exception {
  const BackupFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

Never invalidBackup() => throw const BackupFailure(
  'Bản sao lưu không hợp lệ hoặc dùng phiên bản chưa được hỗ trợ. Dữ liệu hiện có vẫn được giữ.',
);

Map<String, dynamic> backupMap(Object? value, Set<String> fields) {
  if (value is! Map<String, dynamic> ||
      value.length != fields.length ||
      !value.keys.toSet().containsAll(fields)) {
    invalidBackup();
  }
  return value;
}

class BackupAsset {
  BackupAsset(this.name, Map<String, Uint8List> files)
    : files = Map.unmodifiable(
        files.map(
          (k, v) => MapEntry(k, Uint8List.fromList(v).asUnmodifiableView()),
        ),
      ) {
    if (!isCharacterAssetName(name) || files.isEmpty || files.length > 5) {
      invalidBackup();
    }
    final package = name.endsWith('.character');
    final required = package
        ? {'source.bin', 'atlas.png', 'preview.png', 'asset.json'}
        : {'source.bin'};
    if (!files.keys.toSet().containsAll(required) ||
        files.keys.any(
          (k) => !{...required, if (package) 'license.txt'}.contains(k),
        )) {
      invalidBackup();
    }
    for (final e in files.entries) {
      final limit = switch (e.key) {
        'source.bin' => package ? 16 * 1024 * 1024 : 4 * 1024 * 1024,
        'atlas.png' => 8 * 1024 * 1024,
        'preview.png' => 128 * 1024,
        _ => 65536,
      };
      if (e.value.isEmpty || e.value.length > limit) invalidBackup();
    }
    if (sha256.convert(files['source.bin']!).toString() !=
        name.substring(0, 64)) {
      invalidBackup();
    }
  }
  final String name;
  final Map<String, Uint8List> files;
  int get byteLength => files.values.fold(0, (n, v) => n + v.length);
  Map<String, dynamic> toJson() => {
    'name': name,
    'files': {for (final e in files.entries) e.key: base64Encode(e.value)},
  };
  factory BackupAsset.fromJson(Object? value) {
    final j = backupMap(value, {'name', 'files'});
    if (j['name'] is! String || j['files'] is! Map<String, dynamic>) {
      invalidBackup();
    }
    final files = j['files'] as Map<String, dynamic>;
    if (files.length > 5 ||
        files.values.any((v) => v is! String || v.length > 24 * 1024 * 1024)) {
      invalidBackup();
    }
    return BackupAsset(j['name'] as String, {
      for (final e in files.entries) e.key: base64Decode(e.value as String),
    });
  }
}

/// Portable user data only: no credentials, device identity, outbox or delivered
/// alarms. Restore adds independent copies; it never overwrites existing tasks.
class BackupSnapshot {
  BackupSnapshot({
    required this.id,
    required this.owner,
    required this.createdAt,
    required List<SyncRecord> records,
    required Map<String, dynamic> settings,
    required List<BackupAsset> assets,
  }) : records = List.unmodifiable(records),
       assets = List.unmodifiable(assets),
       _settingsJson = jsonEncode(settings) {
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) ||
        (owner != null && (owner!.isEmpty || owner!.length > 128)) ||
        records.length > 5000 ||
        records.any((r) => r.deleted) ||
        records.map((r) => r.key).toSet().length != records.length ||
        assets.length > 128 ||
        assets.map((a) => a.name).toSet().length != assets.length ||
        assets.fold<int>(0, (n, a) => n + a.byteLength) > 32 * 1024 * 1024 ||
        utf8.encode(jsonEncode([for (final r in records) r.toJson()])).length >
            4 * 1024 * 1024 ||
        utf8.encode(jsonEncode(settings)).length > 65536) {
      invalidBackup();
    }
    validInstant(createdAt, required: true);
    backupMap(settings, {
      'preferences',
      'layout',
      'expressions',
      'dashboard',
      'notifications',
    });
    final names = assets.map((a) => a.name).toSet();
    final prefs = settings['preferences'];
    if (prefs is! Map<String, dynamic>) invalidBackup();
    final p = AppPreferences.fromJson(prefs);
    if (canonicalJson(prefs) != canonicalJson(p.toJson())) invalidBackup();
    if (p.assetName != null && !names.contains(p.assetName)) invalidBackup();
    final expressions = settings['expressions'];
    if (expressions is! Map<String, dynamic> || expressions.length > 4) {
      invalidBackup();
    }
    for (final e in expressions.entries) {
      if (!CompanionExpression.values.any((v) => v.name == e.key) ||
          !names.contains(e.value)) {
        invalidBackup();
      }
    }
    final layout = settings['layout'];
    if (layout is! Map<String, dynamic>) invalidBackup();
    CompanionLayout.fromJson(layout).validate();
  }
  final String id, createdAt;
  final String? owner;
  final List<SyncRecord> records;
  final String _settingsJson;
  Map<String, dynamic> get settings =>
      jsonDecode(_settingsJson) as Map<String, dynamic>;
  final List<BackupAsset> assets;
  int get taskCount => records.where((r) => r.kind == SyncKind.task).length;
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'id': id,
    'owner': owner,
    'createdAt': createdAt,
    'records': [for (final r in records) r.toJson()],
    'settings': settings,
    'assets': [for (final a in assets) a.toJson()],
  };
  factory BackupSnapshot.fromJson(Object? value) {
    try {
      final j = backupMap(value, {
        'schema',
        'id',
        'owner',
        'createdAt',
        'records',
        'settings',
        'assets',
      });
      if (j['schema'] != 1 ||
          j['records'] is! List ||
          j['assets'] is! List ||
          (j['records'] as List).length > 5000 ||
          (j['assets'] as List).length > 128) {
        invalidBackup();
      }
      return BackupSnapshot(
        id: j['id'] as String,
        owner: j['owner'] as String?,
        createdAt: j['createdAt'] as String,
        records: [
          for (final r in j['records'])
            SyncRecord.fromJson((r as Map).cast<String, dynamic>()),
        ],
        settings: (j['settings'] as Map).cast<String, dynamic>(),
        assets: [for (final a in j['assets']) BackupAsset.fromJson(a)],
      );
    } on BackupFailure {
      rethrow;
    } catch (_) {
      invalidBackup();
    }
  }
}
