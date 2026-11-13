import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../account_sync/data/copy_workspace.dart';
import '../../account_sync/data/sync_store.dart';
import '../../account_sync/data/workspace_records.dart';
import '../../account_sync/domain/sync_record.dart';
import '../../assistant/domain/daily_assistant.dart';
import '../../companion/data/asset_importer.dart';
import '../../companion/domain/companion.dart';
import '../../reminders/domain/reminder.dart';
import '../../tasks/data/database.dart';
import '../domain/backup_snapshot.dart';

/// The host must quiesce controller, sync and OS schedulers around these calls.
/// Assets are additive with a durable rollback journal; the restore marker and
/// all logical records commit together in SQLite. No prior asset is overwritten.
abstract final class BackupService {
  static Future<void> _checkOwner(
    SqliteTaskRepository repo,
    String? owner,
  ) async {
    final stored = await WorkspaceRecords(repo).records
        .get('account', 'session');
    if (stored?['ownerId'] != owner) {
      throw const BackupFailure(
        'Không truy cập bản sao lưu của không gian tài khoản khác.',
      );
    }
  }

  static Future<BackupSnapshot> capture(
    SqliteTaskRepository repo,
    StaticAssetImporter importer,
    String? owner, {
    String? backupOwner,
  }) async {
    await _checkOwner(repo, owner);
    if (owner != null &&
        (await SyncStore(repo, owner).conflicts()).isNotEmpty) {
      throw const BackupFailure(
        'Hãy giải quyết các xung đột đồng bộ trước khi sao lưu để giữ đủ các bản đang sửa.',
      );
    }
    final assets = <BackupAsset>[];
    for (final name in importer.installed()) {
      assets.add(BackupAsset(name, await importer.backupFiles(name)));
    }
    final records = WorkspaceRecords(repo);
    return repo.db.transaction(
      () async => BackupSnapshot(
        id: const Uuid().v4(),
        owner: backupOwner ?? owner,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        records: (await records.read()).values.toList(),
        assets: assets,
        settings: {
          'preferences': AppPreferences.fromJson(await repo.readPreferences())
              .toJson(),
          'layout': CompanionLayout.fromJson(
            await records.records.get('companion_local', 'layout'),
          ).toJson(),
          'expressions':
              await records.records.get('companion_local', 'expressions') ?? {},
          'dashboard': DashboardPreferences.fromJson(
            await records.records.get('assistant', 'dashboard'),
          ).toJson(),
          'notifications': NotificationPreferences.fromJson(
            await records.records.get('notifications', 'settings') ?? {},
          ).toJson(),
        },
      ),
    );
  }

  static Future<void> validate(BackupSnapshot snapshot) async {
    final db = DaymindDatabase(NativeDatabase.memory());
    try {
      final records = WorkspaceRecords(SqliteTaskRepository(db));
      await db.delete(db.categories).go();
      final sorted = [...snapshot.records]
        ..sort(
          (a, b) => SyncStore.order(a.kind).compareTo(SyncStore.order(b.kind)),
        );
      for (final r in sorted) {
        await records.apply(r);
      }
      await records.read(); // Cross-record/category/rule/occurrence validation.
      final rawNotifications = (snapshot.settings['notifications'] as Map)
          .cast<String, dynamic>();
      final notifications = NotificationPreferences.fromJson(rawNotifications);
      notifications.validate();
      if (canonicalJson(rawNotifications) !=
              canonicalJson(notifications.toJson()) ||
          canonicalJson(snapshot.settings['layout']) !=
              canonicalJson(
                CompanionLayout.fromJson(
                  (snapshot.settings['layout'] as Map).cast(),
                ).toJson(),
              )) {
        invalidBackup();
      }
      final cards = snapshot.settings['dashboard'];
      if (cards is! Map<String, dynamic> ||
          canonicalJson(cards) !=
              canonicalJson(DashboardPreferences.fromJson(cards).toJson())) {
        invalidBackup();
      }
    } finally {
      await db.close();
    }
  }

  static File _journal(StaticAssetImporter importer) =>
      File(p.join(importer.directory.parent.path, '.backup-restore.json'));

  static Future<void> restore(
    BackupSnapshot snapshot,
    SqliteTaskRepository repo,
    StaticAssetImporter importer,
    String? owner, {
    required bool companionSettings,
    String? backupOwner,
  }) async {
    await _checkOwner(repo, owner);
    if (snapshot.owner != (backupOwner ?? owner)) {
      throw const BackupFailure(
        'Bản sao lưu thuộc không gian khác. Hãy mở đúng tài khoản hoặc chế độ cục bộ đã tạo bản sao lưu.',
      );
    }
    final records = WorkspaceRecords(repo);
    if (await records.records.get('backup_restore', snapshot.id) != null) {
      throw const BackupFailure(
        'Bản sao lưu này đã được khôi phục ở đây. Không tạo thêm công việc trùng.',
      );
    }
    await recover(repo, importer);
    await validate(snapshot);
    final stage = Directory(
      p.join(importer.directory.parent.path, '.restore-${const Uuid().v4()}'),
    );
    await stage.create();
    final staged = StaticAssetImporter(
      Directory(p.join(stage.path, 'characters')),
    );
    final existing = importer.installed().toSet(), added = <String>[];
    final journal = _journal(importer);
    bool journalWritten = false, committed = false;
    try {
      for (final asset in snapshot.assets) {
        await staged.restoreBackupFiles(asset.name, asset.files);
        final type = await FileSystemEntity.type(
          p.join(importer.directory.path, asset.name),
          followLinks: false,
        );
        if (existing.contains(asset.name)) {
          BackupAsset(asset.name, await importer.backupFiles(asset.name));
        } else {
          if (type != FileSystemEntityType.notFound) invalidBackup();
          added.add(asset.name);
        }
      }
      final receipt = {
        'schema': 1,
        'id': snapshot.id,
        'stage': p.basename(stage.path),
        'added': added,
      };
      final temporary = File(p.join(stage.path, 'journal.tmp'));
      await temporary.writeAsString(jsonEncode(receipt), flush: true);
      await temporary.rename(journal.path);
      journalWritten = true;
      for (final asset in snapshot.assets.where(
        (a) => added.contains(a.name),
      )) {
        await importer.restoreBackupFiles(asset.name, asset.files);
      }
      await repo.db.transaction(() async {
        if (await records.records.get('backup_restore', snapshot.id) != null) {
          throw const BackupFailure('Bản sao lưu đã được khôi phục.');
        }
        await copyWorkspace(snapshot.records, records);
        if (companionSettings) {
          final prefs = AppPreferences.fromJson(
            (snapshot.settings['preferences'] as Map).cast(),
          ).copyWith(windowsTrayEnabled: true);
          await repo.writePreferences(prefs.toJson());
          await records.records.put(
            'companion_local',
            'layout',
            (snapshot.settings['layout'] as Map).cast(),
          );
          await records.records.put(
            'companion_local',
            'expressions',
            (snapshot.settings['expressions'] as Map).cast(),
          );
          await records.records.put(
            'assistant',
            'dashboard',
            (snapshot.settings['dashboard'] as Map).cast(),
          );
          final profile = snapshot.records
              .where((r) => r.kind == SyncKind.companionProfile)
              .firstOrNull;
          await records.records.put(
            'companion_profile',
            'primary',
            profile?.data ??
                CompanionProfile(personality: prefs.personality).toJson(),
          );
        }
        final current = NotificationPreferences.fromJson(
          await records.records.get('notifications', 'settings') ?? {},
        );
        final selected = companionSettings
            ? (snapshot.settings['notifications'] as Map)
                  .cast<String, dynamic>()
            : current.toJson();
        await records.records.put('notifications', 'settings', {
          ...selected,
          'primaryDevice': false,
          'digestEnabled': false,
          'permissionPrompted': current.permissionPrompted,
        });
        if (owner != null) {
          await records.records.put('notifications', 'local_device', {
            'enabled': false,
          });
        }
        // Floating is an explicit device opt-in, never inherited from a backup.
        await records.records.put('companion_local', 'floating', {
          'enabled': false,
          'size': 112,
          'topmost': false,
          'clickThrough': false,
        });
        await records.records.put('backup_restore', snapshot.id, {
          'committed': true,
        });
      });
      committed = true;
    } finally {
      await staged.drain();
      if (journalWritten) {
        try {
          await recover(repo, importer);
        } catch (_) {
          if (!committed) rethrow;
        }
      } else if (await stage.exists()) {
        await stage.delete(recursive: true);
      }
    }
  }

  static Future<void> recover(
    SqliteTaskRepository repo,
    StaticAssetImporter importer, {
    bool removeOrphans = false,
  }) async {
    final journal = _journal(importer);
    final type = await FileSystemEntity.type(journal.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      if (removeOrphans) await _removeOrphans(importer);
      return;
    }
    if (type != FileSystemEntityType.file || await journal.length() > 65536) {
      invalidBackup();
    }
    final j = backupMap(jsonDecode(await journal.readAsString()), {
      'schema',
      'id',
      'stage',
      'added',
    });
    final id = j['id'], stageName = j['stage'], raw = j['added'];
    if (j['schema'] != 1 ||
        id is! String ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) ||
        stageName is! String ||
        !RegExp(r'^\.restore-[a-f0-9-]{36}$').hasMatch(stageName) ||
        raw is! List ||
        raw.length > 128 ||
        raw.any((v) => v is! String || !isCharacterAssetName(v))) {
      invalidBackup();
    }
    final records = WorkspaceRecords(repo);
    if (await records.records.get('backup_restore', id) == null) {
      final prefs = AppPreferences.fromJson(await repo.readPreferences()),
          expressions =
              await records.records.get('companion_local', 'expressions') ?? {};
      for (final name in raw.cast<String>()) {
        if (prefs.assetName == name || expressions.containsValue(name)) {
          throw const BackupFailure(
            'Cần kiểm tra bản khôi phục bị gián đoạn; ảnh đang dùng vẫn được giữ.',
          );
        }
        final path = p.join(importer.directory.path, name);
        final t = await FileSystemEntity.type(path, followLinks: false);
        if (t == FileSystemEntityType.notFound) continue;
        if (t !=
            (name.endsWith('.character')
                ? FileSystemEntityType.directory
                : FileSystemEntityType.file)) {
          invalidBackup();
        }
        await importer.remove(name);
      }
    }
    final stage = Directory(p.join(importer.directory.parent.path, stageName));
    final stageType = await FileSystemEntity.type(
      stage.path,
      followLinks: false,
    );
    if (stageType == FileSystemEntityType.directory) {
      await stage.delete(recursive: true);
    } else if (stageType != FileSystemEntityType.notFound) {
      invalidBackup();
    }
    await journal.delete();
    if (removeOrphans) await _removeOrphans(importer);
  }

  static Future<void> _removeOrphans(StaticAssetImporter importer) async {
    // Called only before a workspace is exposed, under the host's lifecycle
    // serialization (and the Windows process lock). Never scan during imports.
    for (final pair in [
      (importer.directory.parent, '.restore-'),
      (importer.directory, '.install-'),
    ]) {
      final folder = pair.$1;
      if (await FileSystemEntity.type(folder.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        continue;
      }
      await for (final entry in folder.list(followLinks: false)) {
        if (entry is Directory &&
            RegExp('^${RegExp.escape(pair.$2)}[a-f0-9-]{36}\$')
                .hasMatch(p.basename(entry.path))) {
          await entry.delete(recursive: true);
        }
      }
    }
  }
}
