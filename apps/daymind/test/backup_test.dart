import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:daymind_smart/features/backup/application/backup_service.dart';
import 'package:daymind_smart/features/backup/data/backup_codec.dart';
import 'package:daymind_smart/features/backup/domain/backup_snapshot.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';
import 'package:daymind_smart/features/recurrence/application/recurrence_service.dart';
import 'package:daymind_smart/features/recurrence/domain/recurrence.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';
import 'package:daymind_smart/features/tasks/domain/task.dart';

import 'character_zip_test.dart' show Entry, zip;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  zones.initializeTimeZones();
  late Directory root;
  late DaymindDatabase db, targetDb;
  late SqliteTaskRepository source, target;
  late StaticAssetImporter art, targetArt;
  late BackupSnapshot snapshot;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('daymind-backup-test-');
    db = DaymindDatabase(NativeDatabase.memory());
    targetDb = DaymindDatabase(NativeDatabase.memory());
    source = SqliteTaskRepository(db);
    target = SqliteTaskRepository(targetDb);
    art = StaticAssetImporter(Directory('${root.path}/source/characters'));
    targetArt = StaticAssetImporter(
      Directory('${root.path}/target/characters'),
    );
    await targetArt.directory.parent.create(recursive: true);
    final name = await art.installPrepared(
      await art.prepareCharacter(
        File('test/fixtures/three_sprite_frames.zip'),
        'fixture.zip',
      ),
      rightsConfirmed: true,
    );
    await source.writePreferences(
      const AppPreferences().copyWith(assetName: name).toJson(),
    );
    final r = RecurrenceService(source);
    final id = await source.save(
      TaskDraft(
        title: 'Private backup task',
        dueAt: DateTime.now().add(const Duration(days: 1)),
      ),
    );
    final task = (await source.list()).single;
    await r.configure(
      id,
      RepeatChange(
        enabled: true,
        spec: RepeatSpec(
          frequency: RepeatFrequency.daily,
          zone: 'Asia/Ho_Chi_Minh',
          firstDate: DateTime.now().toUtc().toIso8601String().substring(0, 10),
        ),
      ),
      TaskDraft.fromTask(task),
    );
    await r.materialize(await source.list());
    final occurrence = r.project(await source.list()).first;
    await r.toggle(occurrence);
    snapshot = await BackupService.capture(source, art, null);
  });
  tearDown(() async {
    await art.drain();
    await targetArt.drain();
    await db.close();
    await targetDb.close();
    await root.delete(recursive: true);
  });
  test('password AEAD authenticates the header and source; malformed framing is rejected before KDF', () async {
    const password = 'test-only-backup-passphrase';
    final encrypted = await BackupCodec.encrypt(snapshot, password);
    expect(await BackupCodec.encrypt(snapshot, password), isNot(encrypted));
    expect(
      String.fromCharCodes(encrypted),
      isNot(contains('Private backup task')),
    );
    final decoded = await BackupCodec.decrypt(encrypted, password);
    expect(decoded.toJson(), snapshot.toJson());
    await expectLater(
      BackupCodec.decrypt(encrypted, 'incorrect-test-password'),
      throwsA(isA<BackupFailure>()),
    );
    final tampered = Uint8List.fromList(encrypted)..[24] ^= 1;
    await expectLater(
      BackupCodec.decrypt(tampered, password),
      throwsA(isA<BackupFailure>()),
    );
    for (final bad in [
      Uint8List(0),
      encrypted.sublist(0, encrypted.length - 1),
      Uint8List.fromList([...encrypted, 0]),
    ]) {
      expect(
        () => BackupCodec.decrypt(bad, password),
        throwsA(isA<BackupFailure>()),
      );
    }
    expect(
      () => BackupCodec.encrypt(snapshot, 'short'),
      throwsA(isA<BackupFailure>()),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
  test('restore appends independent recurrence copies, retains existing tasks/artwork, pauses alerts and is idempotent', () async {
    final oldId = await target.save(
      const TaskDraft(title: 'Keep existing work'),
    );
    await BackupService.restore(
      snapshot,
      target,
      targetArt,
      null,
      companionSettings: true,
    );
    final tasks = await target.list();
    expect(tasks, hasLength(2));
    expect(tasks.any((t) => t.id == oldId), isTrue);
    expect(
      tasks.any(
        (t) =>
            t.id ==
            (snapshot.records.firstWhere((r) => r.kind.name == 'task').id),
      ),
      isFalse,
    );
    final recurrence = RecurrenceService(target);
    await recurrence.reload();
    expect((await recurrence.records.list('recurrence')), hasLength(1));
    expect(
      recurrence.project(tasks).any((t) => t.status == TaskStatus.completed),
      isTrue,
    );
    expect(
      (await recurrence.records.get(
        'notifications',
        'settings',
      ))!['primaryDevice'],
      isFalse,
    );
    expect(
      (await recurrence.records.get(
        'notifications',
        'settings',
      ))!['digestEnabled'],
      isFalse,
    );
    expect(await targetDb.select(targetDb.reminderEvents).get(), isEmpty);
    expect(targetArt.installed(), art.installed());
    final restored = (await targetArt.character(targetArt.installed().single))!;
    expect(
      await restored.source.readAsBytes(),
      await art.resolve(art.installed().single)!.readAsBytes(),
    );
    expect(
      restored.metadata.name,
      (await art.character(art.installed().single))!.metadata.name,
    );
    await expectLater(
      BackupService.restore(
        snapshot,
        target,
        targetArt,
        null,
        companionSettings: true,
      ),
      throwsA(isA<BackupFailure>()),
    );
    expect(await target.list(), hasLength(2));
  });
  test('wrong owner and broken relations do not install artwork or change existing data', () async {
    await target.save(const TaskDraft(title: 'Keep'));
    await expectLater(
      BackupService.restore(
        snapshot,
        target,
        targetArt,
        'other-owner',
        companionSettings: false,
      ),
      throwsA(isA<BackupFailure>()),
    );
    final json = snapshot.toJson();
    final list = json['records'] as List;
    list.removeWhere((r) => r['kind'] == 'task');
    final broken = BackupSnapshot.fromJson(json);
    await expectLater(
      BackupService.restore(
        broken,
        target,
        targetArt,
        null,
        companionSettings: false,
      ),
      throwsA(anything),
    );
    expect((await target.list()).single.title, 'Keep');
    expect(targetArt.installed(), isEmpty);
  });
  test('a real SQL failure rolls back all copied rows and removes only newly installed artwork', () async {
    await target.save(const TaskDraft(title: 'Keep'));
    await targetDb.customStatement(
      "CREATE TRIGGER block_restore BEFORE INSERT ON tasks WHEN NEW.title='Private backup task' BEGIN SELECT RAISE(ABORT,'fixture rollback'); END",
    );
    await expectLater(
      BackupService.restore(
        snapshot,
        target,
        targetArt,
        null,
        companionSettings: true,
      ),
      throwsA(anything),
    );
    expect((await target.list()).single.title, 'Keep');
    expect(targetArt.installed(), isEmpty);
    expect(
      File('${targetArt.directory.parent.path}/.backup-restore.json')
          .existsSync(),
      isFalse,
    );
    expect(
      targetArt.directory.parent.listSync().any(
        (f) => f.path.contains('.restore-'),
      ),
      isFalse,
    );
  });
  test('interrupted file commit is recovered from its journal before the workspace resumes', () async {
    final asset = snapshot.assets.single;
    await targetArt.restoreBackupFiles(asset.name, asset.files);
    final stage = Directory(
      '${targetArt.directory.parent.path}/.restore-${snapshot.id}',
    );
    await stage.create();
    await File('${targetArt.directory.parent.path}/.backup-restore.json')
        .writeAsString(
          jsonEncode({
            'schema': 1,
            'id': snapshot.id,
            'stage': stage.uri.pathSegments.where((v) => v.isNotEmpty).last,
            'added': [asset.name],
          }),
        );
    await BackupService.recover(target, targetArt);
    expect(targetArt.installed(), isEmpty);
    expect(stage.existsSync(), isFalse);
  });
  test(
    'authenticated backup input cannot bypass the Live2D model gate',
    () async {
      final original = snapshot.assets.single;
      final files = {...original.files};
      files['source.bin'] = zip([
        Entry('avatar.model3.json', utf8.encode('{}')),
      ]);
      final hash = sha256.convert(files['source.bin']!).toString(),
          name = '$hash.character';
      final metadata =
          jsonDecode(utf8.decode(files['asset.json']!)) as Map<String, dynamic>;
      metadata['sourceHash'] = hash;
      files['asset.json'] = Uint8List.fromList(
        utf8.encode(jsonEncode(metadata)),
      );
      final json = snapshot.toJson();
      json['assets'] = [BackupAsset(name, files).toJson()];
      json['settings']['preferences']['assetName'] = name;
      final crafted = BackupSnapshot.fromJson(json);
      await expectLater(
        BackupService.restore(
          crafted,
          target,
          targetArt,
          null,
          companionSettings: true,
        ),
        throwsA(anything),
      );
      expect(await target.list(), isEmpty);
      expect(targetArt.installed(), isEmpty);
      expect(
        targetArt.directory.parent.listSync().any(
          (e) => e.path.contains('.restore-'),
        ),
        isFalse,
      );
    },
  );
  test('startup removes only reserved orphan stages and retains a committed restored asset', () async {
    final prefix = targetArt.directory.parent.path;
    await Directory('$prefix/.restore-${snapshot.id}').create();
    final keep = await Directory('$prefix/.restore-user-note').create();
    await BackupService.recover(target, targetArt, removeOrphans: true);
    expect(Directory('$prefix/.restore-${snapshot.id}').existsSync(), isFalse);
    expect(keep.existsSync(), isTrue);
    await BackupService.restore(
      snapshot,
      target,
      targetArt,
      null,
      companionSettings: false,
    );
    final stage = await Directory('$prefix/.restore-${snapshot.id}').create();
    await File('$prefix/.backup-restore.json').writeAsString(
      jsonEncode({
        'schema': 1,
        'id': snapshot.id,
        'stage': '.restore-${snapshot.id}',
        'added': [snapshot.assets.single.name],
      }),
    );
    await BackupService.recover(target, targetArt, removeOrphans: true);
    expect(targetArt.installed(), [snapshot.assets.single.name]);
    expect(stage.existsSync(), isFalse);
  });
}
