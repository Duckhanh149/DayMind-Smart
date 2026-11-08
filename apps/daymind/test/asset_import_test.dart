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
