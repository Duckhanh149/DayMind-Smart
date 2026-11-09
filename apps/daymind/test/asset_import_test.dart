import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<Uint8List> png(int width, int height) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xff95b76c),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }

  test('dimension and library budgets reject large assets; narrow images remain bounded', () async {
    final temp = await Directory.systemTemp.createTemp('daymind-budget-');
    final importer = StaticAssetImporter(temp);
    await expectLater(
      importer.installBytes(await png(2049, 1), 'wide.png'),
      throwsA(anything),
    );
    expect(importer.installed(), isEmpty);
    final name = await importer.installBytes(await png(1, 2048), 'narrow.png');
    expect(importer.installed(), [name]);
    final budget = await File('${temp.path}/budget').open(mode: FileMode.write);
    await budget.truncate(32 * 1024 * 1024);
    await budget.close();
    await expectLater(
      importer.installBytes(await png(8, 8), 'over-budget.png'),
      throwsA(anything),
    );
    expect(importer.installed(), [name]);
    await temp.delete(recursive: true);
  });
  test('concurrent imports share count budget, deduplicate at capacity and recover after failure', () async {
    final temp = await Directory.systemTemp.createTemp('daymind-count-');
    addTearDown(() => temp.delete(recursive: true));
    final importer = StaticAssetImporter(temp);
    for (var i = 0; i < StaticAssetImporter.maxFiles - 1; i++) {
      await File('${temp.path}/reserved-$i').writeAsBytes([0]);
    }
    final first = await png(8, 8), second = await png(9, 9);
    final results = await Future.wait([
      importer
          .installBytes(first, 'first.png')
          .then<Object>((v) => v, onError: (Object e) => e),
      importer
          .installBytes(second, 'second.png')
          .then<Object>((v) => v, onError: (Object e) => e),
    ]);
    expect(results.whereType<String>(), hasLength(1));
    expect(importer.installed(), hasLength(1));
    expect(await importer.installBytes(first, 'duplicate.png'), results.first);
    await importer.remove(results.first as String);
    expect(await importer.installBytes(second, 'second.png'), isA<String>());
    expect(
      (await temp.list().toList()).any((f) => f.path.endsWith('.tmp')),
      isFalse,
    );
  });
  test(
    'library symlinks cannot be selected, overwritten or followed on import',
    () async {
      final temp = await Directory.systemTemp.createTemp('daymind-links-');
      addTearDown(() => temp.delete(recursive: true));
      final library = Directory('${temp.path}/library');
      final importer = StaticAssetImporter(library);
      final bytes = await png(8, 8);
      final name = await importer.installBytes(bytes, 'first.png');
      await importer.remove(name);
      final outside = await File('${temp.path}/outside.png')
          .writeAsBytes(bytes);
      await Link('${library.path}/$name').create(outside.path);
      expect(importer.resolve(name), isNull);
      expect(importer.installed(), isEmpty);
      await expectLater(
        importer.installBytes(bytes, 'again.png'),
        throwsA(anything),
      );
      await expectLater(
        importer.install(File('${library.path}/$name'), 'link.png'),
        throwsA(anything),
      );
      expect(await outside.readAsBytes(), bytes);
    },
    skip: Platform.isWindows
        ? 'Creating symlinks requires Windows host privileges; Linux gate exercises traversal rejection.'
        : false,
  );
  test('preview validates without installing; static WebP works and animated WebP is rejected', () async {
    final temp = await Directory.systemTemp.createTemp('daymind-preview-');
    addTearDown(() => temp.delete(recursive: true));
    final importer = StaticAssetImporter(Directory('${temp.path}/library'));
    final preview = await importer.prepare(
      File('test/fixtures/static.webp'),
      'leaf.webp',
    );
    expect(importer.installed(), isEmpty);
    expect(() => preview.bytes[0] = 0, throwsUnsupportedError);
    final installed = await importer.installPrepared(preview);
    expect(installed.endsWith('.webp'), isTrue);
    await expectLater(
      importer.prepare(File('test/fixtures/animated.webp'), 'animated.webp'),
      throwsA(anything),
    );
    expect(importer.installed(), [installed]);
  });
  test('reject ZIP, disguised files, oversized files and unsafe names', () {
    expect(
      () => StaticAssetImporter.validateSignature(
        Uint8List.fromList([80, 75, 3, 4]),
        'model.zip',
      ),
      throwsA(anything),
    );
    expect(
      () => StaticAssetImporter.validateSignature(Uint8List(30), 'fake.png'),
      throwsA(anything),
    );
    expect(
      () => StaticAssetImporter.validateSignature(
        Uint8List(StaticAssetImporter.maxBytes + 1),
        'big.png',
      ),
      throwsA(anything),
    );
    expect(
      () => StaticAssetImporter.validateSignature(Uint8List(30), '../x.png'),
      throwsA(anything),
    );
  });
  test(
    'decodes and atomically installs valid PNG; rejects corrupt content',
    () async {
      final temp = await Directory.systemTemp.createTemp('daymind-assets-');
      final importer = StaticAssetImporter(temp);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 8, 8),
        ui.Paint()..color = const ui.Color(0xff95b76c),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(8, 8);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final bytes = data!.buffer.asUint8List();
      final name = await importer.installBytes(bytes, 'mam.png');
      expect(importer.resolve(name)!.existsSync(), true);
      expect(await importer.installBytes(bytes, 'another.png'), name);
      expect(await temp.list().length, 1);
      expect(importer.resolve('../outside.png'), isNull);
      await expectLater(
        importer.installBytes(bytes.sublist(0, 24), 'bad.png'),
        throwsA(anything),
      );
      expect(await temp.list().length, 1);
      expect(importer.installed(), [name]);
      await importer.remove(name);
      expect(importer.installed(), isEmpty);
      await temp.delete(recursive: true);
    },
  );
}
