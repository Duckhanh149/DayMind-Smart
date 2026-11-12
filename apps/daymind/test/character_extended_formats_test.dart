import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/companion/data/image_preflight.dart';
import 'package:daymind_smart/features/backup/domain/backup_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('6 MiB BMP imports beyond old 32 MiB library quota and restores exact source', () async {
    const w = 2048, h = 1024, size = 54 + w * h * 3;
    final bytes = Uint8List(size)..fillRange(54, size, 255);
    final d = ByteData.sublistView(bytes);
    bytes[0] = 66;
    bytes[1] = 77;
    d.setUint32(2, size, Endian.little);
    d.setUint32(10, 54, Endian.little);
    d.setUint32(14, 40, Endian.little);
    d.setUint32(18, w, Endian.little);
    d.setUint32(22, h, Endian.little);
    d.setUint16(26, 1, Endian.little);
    d.setUint16(28, 24, Endian.little);
    final root = await Directory.systemTemp.createTemp('daymind-large-bmp-');
    addTearDown(() => root.delete(recursive: true));
    final library = await Directory('${root.path}/library').create();
    final reserved = await File('${library.path}/reserved')
        .open(mode: FileMode.write);
    await reserved.truncate(40 * 1024 * 1024);
    await reserved.close();
    final importer = StaticAssetImporter(library);
    final name = await importer.installBytes(bytes, 'large.bmp');
    final asset = BackupAsset(name, {'source.bin': bytes});
    final restored = StaticAssetImporter(Directory('${root.path}/restored'));
    expect(await restored.restoreBackupFiles(asset.name, asset.files), name);
    expect(await restored.resolve(name)!.readAsBytes(), bytes);
  });
  test('JPEG truncation and oversized BMP headers fail before decoder', () {
    final jpeg = File('test/fixtures/flat_character.jpg').readAsBytesSync();
    expect(
      () => CharacterImageProbe.inspect(
        Uint8List.sublistView(jpeg, 0, jpeg.length - 2),
      ),
      throwsA(isA<CharacterImageFailure>()),
    );
    final bmp = File('test/fixtures/flat_character.bmp').readAsBytesSync();
    ByteData.sublistView(bmp).setInt32(18, 1000000, Endian.little);
    expect(
      () => CharacterImageProbe.inspect(bmp),
      throwsA(isA<CharacterImageFailure>()),
    );
  });
}
