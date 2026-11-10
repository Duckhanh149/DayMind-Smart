import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/companion/data/character_preparer.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp, library;
  late StaticAssetImporter importer;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('daymind-character-store-');
    library = Directory('${temp.path}/library');
    importer = StaticAssetImporter(library);
  });
  tearDown(() async {
    await importer.drain();
    await temp.delete(recursive: true);
  });
  test('preview has no side effects, rights confirmation precedes atomic install and source stays exact', () async {
    final source = File('test/fixtures/three_frames.gif'),
        bytes = await source.readAsBytes();
    final prepared = await importer.prepareCharacter(source, 'leaf.gif');
    expect(prepared.animation!.metadata.frames, hasLength(3));
    expect(library.existsSync(), isFalse);
    await expectLater(importer.installPrepared(prepared), throwsA(anything));
    expect(library.existsSync(), isFalse);
    final name = await importer.installPrepared(
      prepared,
      rightsConfirmed: true,
    );
    expect(name, '${sha256.convert(bytes)}.character');
    expect(await importer.resolve(name)!.readAsBytes(), bytes);
    expect(importer.installed(), [name]);
    expect((await importer.character(name))!.metadata.frames, hasLength(3));
    expect((await importer.renderFile(name))!.existsSync(), isTrue);
    expect(
      library.listSync().any((e) => e.path.contains('.install-')),
      isFalse,
    );
  });
  test('concurrent duplicate installs commit one package and remove all managed content', () async {
    final prepared = await importer.prepareCharacter(
      File('test/fixtures/valid_character.zip'),
      'plant.zip',
    );
    final names = await Future.wait([
      importer.installPrepared(prepared, rightsConfirmed: true),
      importer.installPrepared(prepared, rightsConfirmed: true),
    ]);
    expect(names.toSet(), hasLength(1));
    expect(importer.installed(), hasLength(1));
    final a = await importer.character(names.first);
    expect(a!.metadata.name, 'Mầm thử nghiệm');
    expect(
      await a.source.readAsBytes(),
      await File('test/fixtures/valid_character.zip').readAsBytes(),
    );
    await importer.remove(names.first);
    expect(importer.installed(), isEmpty);
    expect(a.source.existsSync(), isFalse);
    expect(a.preview.existsSync(), isFalse);
  });
  test('quota rejection and invalid input leave previous package intact without staging residues', () async {
    final old = await importer.installPrepared(
      await importer.prepareCharacter(
        File('test/fixtures/three_frames.gif'),
        'leaf.gif',
      ),
      rightsConfirmed: true,
    );
    final next = await importer.prepareCharacter(
      File('test/fixtures/valid_character.zip'),
      'plant.zip',
    );
    final reserved = await File('${library.path}/reserved')
        .open(mode: FileMode.write);
    await reserved.truncate(32 * 1024 * 1024);
    await reserved.close();
    await expectLater(
      importer.installPrepared(next, rightsConfirmed: true),
      throwsA(anything),
    );
    expect(importer.installed(), [old]);
    expect((await importer.character(old))!.source.existsSync(), isTrue);
    expect(
      library.listSync().any((e) => e.path.contains('.install-')),
      isFalse,
    );
    await expectLater(
      importer.prepareCharacter(
        File('test/fixtures/three_frames.gif'),
        'fake.zip',
      ),
      throwsA(anything),
    );
    expect(importer.installed(), [old]);
  });
  test('cold loading rejects altered atlas bytes and keeps original data for recovery', () async {
    final name = await importer.installPrepared(
      await importer.prepareCharacter(
        File('test/fixtures/three_frames.gif'),
        'leaf.gif',
      ),
      rightsConfirmed: true,
    );
    final path = '${library.path}/$name';
    await File('$path/atlas.png').writeAsBytes([1, 2, 3]);
    final cold = StaticAssetImporter(library);
    await expectLater(cold.character(name), throwsA(anything));
    expect(
      await cold.resolve(name)!.readAsBytes(),
      await File('test/fixtures/three_frames.gif').readAsBytes(),
    );
    await cold.drain();
  });
  test('cached render metadata cannot bypass a later bounded atlas read or its checksum', () async {
    final name = await importer.installPrepared(
      await importer.prepareCharacter(
        File('test/fixtures/three_frames.gif'),
        'leaf.gif',
      ),
      rightsConfirmed: true,
    );
    final character = (await importer.character(name))!;
    expect(await importer.atlasBytes(character), isNotEmpty);
    final bytes = await character.atlas.readAsBytes();
    await character.atlas.writeAsBytes(
      await File('test/fixtures/metadata.png').readAsBytes(),
    );
    await expectLater(importer.atlasBytes(character), throwsA(anything));
    final file = await character.atlas.open(mode: FileMode.write);
    await file.truncate(8 * 1024 * 1024 + 1);
    await file.close();
    await expectLater(importer.atlasBytes(character), throwsA(anything));
    await character.atlas.writeAsBytes(bytes);
    expect(await importer.atlasBytes(character), bytes);
    final reading = importer.atlasBytes(character);
    final closed = importer.drain();
    await expectLater(reading, throwsA(isA<CharacterImportCancelled>()));
    await closed;
    await library.delete(recursive: true);
    expect(library.existsSync(), isFalse);
  });
  test('profile asset/expression references survive restart and closing drains image work before deletion', () async {
    final name = await importer.installPrepared(
      await importer.prepareCharacter(
        File('test/fixtures/three_frames.gif'),
        'leaf.gif',
      ),
      rightsConfirmed: true,
    );
    final db = DaymindDatabase(NativeDatabase.memory());
    var c = WorkspaceController(SqliteTaskRepository(db), importer);
    await c.load();
    await c.configure((p) => p.copyWith(assetName: name));
    await c.mapExpression(CompanionExpression.happy, name);
    await c.drain();
    c.dispose();
    importer = StaticAssetImporter(library);
    c = WorkspaceController(SqliteTaskRepository(db), importer);
    await c.load();
    expect(c.preferences.assetName, name);
    expect(c.expressionAssets[CompanionExpression.happy], name);
    final flight = importer.character(name);
    final done = c.drain();
    await expectLater(flight, throwsA(isA<CharacterImportCancelled>()));
    await done;
    await library.delete(recursive: true);
    expect(library.existsSync(), isFalse);
    c.dispose();
    await db.close();
  });
  test('draining cancels in-flight normalization and a resumed library can import again', () async {
    late Future<void> drained;
    final preparation = importer.prepareCharacter(
      File('test/fixtures/three_frames.gif'),
      'leaf.gif',
      progress: (done, _) {
        if (done == 1) drained = importer.drain();
      },
    );
    await expectLater(preparation, throwsA(isA<CharacterImportCancelled>()));
    await drained;
    expect(library.existsSync(), isFalse);
    importer.resume();
    final name = await importer.installPrepared(
      await importer.prepareCharacter(
        File('test/fixtures/three_frames.gif'),
        'leaf.gif',
      ),
      rightsConfirmed: true,
    );
    expect(importer.installed(), [name]);
  });
  test('preparation queue is bounded before reading sources and drains cancelled workers', () async {
    final first = importer.prepareCharacter(
      File('test/fixtures/three_frames.gif'),
      'one.gif',
    );
    final second = importer.prepareCharacter(
      File('test/fixtures/three_frames.webp'),
      'two.webp',
    );
    final rejected = importer.prepareCharacter(
      File('not-read.zip'),
      'three.zip',
    );
    await expectLater(
      rejected,
      throwsA(predicate((e) => e.toString().contains('Đang chuẩn bị'))),
    );
    final stopped = importer.drain();
    await expectLater(first, throwsA(isA<CharacterImportCancelled>()));
    await expectLater(second, throwsA(isA<CharacterImportCancelled>()));
    await stopped;
    expect(library.existsSync(), isFalse);
  });
  test(
    'package links are never followed and removing a nested link preserves its target',
    () async {
      final name = await importer.installPrepared(
        await importer.prepareCharacter(
          File('test/fixtures/three_frames.gif'),
          'leaf.gif',
        ),
        rightsConfirmed: true,
      );
      final outside = await File('${temp.path}/outside').writeAsString('keep');
      final root = Directory('${library.path}/$name');
      await File('${root.path}/source.bin').delete();
      await Link('${root.path}/source.bin').create(outside.path);
      expect(importer.resolve(name), isNull);
      await importer.remove(name);
      expect(await outside.readAsString(), 'keep');
      final external = await Directory('${temp.path}/external').create();
      await Link(root.path).create(external.path);
      expect(importer.installed(), isEmpty);
      await expectLater(importer.remove(name), throwsA(anything));
      expect(external.existsSync(), isTrue);
      expect(jsonEncode(importer.installed()), '[]');
    },
    skip: Platform.isWindows
        ? 'Symlink creation needs Windows host privileges; Linux exercises the link guard.'
        : false,
  );
}
