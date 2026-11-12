import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/companion/data/background_cutout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cutout removes border color, preserves enclosed white and rejects multicolor corners', () {
    final pixels = Uint8List(5 * 5 * 4)..fillRange(0, 100, 255);
    for (var y = 1; y < 4; y++) {
      for (var x = 1; x < 4; x++) {
        if (x == 2 && y == 2) continue;
        final i = (y * 5 + x) * 4;
        pixels[i] = 20;
        pixels[i + 1] = 100;
        pixels[i + 2] = 40;
      }
    }
    final result = cutFlatBackground(pixels, 5, 5);
    expect(result[3], 0);
    expect(result[(2 * 5 + 2) * 4 + 3], 255);
    expect(pixels[3], 255);
    pixels[0] = 0;
    expect(() => cutFlatBackground(pixels, 5, 5), throwsFormatException);
  });
  for (final ext in ['jpg', 'bmp']) {
    test(
      '$ext imports, cuts/trims, reopens and leaves original intact',
      () async {
        final root = await Directory.systemTemp.createTemp('daymind-cutout-');
        addTearDown(() => root.delete(recursive: true));
        final importer = StaticAssetImporter(root);
        final file = File('test/fixtures/flat_character.$ext');
        final original = await file.readAsBytes();
        final preview = await importer.prepareCharacter(file, 'character.$ext');
        final uncut = await importer.installPrepared(preview);
        expect(await importer.resolve(uncut)!.readAsBytes(), original);
        final cut = await importer.removeFlatBackground(preview);
        final name = await importer.installPrepared(cut);
        final reopened = await StaticAssetImporter(root).renderFile(name);
        expect(reopened, isNotNull);
        final codec = await ui.instantiateImageCodec(
          await reopened!.readAsBytes(),
        );
        final image = (await codec.getNextFrame()).image;
        expect(image.width, lessThan(32));
        expect(image.height, lessThan(32));
        image.dispose();
        codec.dispose();
        expect(await file.readAsBytes(), original);
      },
    );
  }
}
