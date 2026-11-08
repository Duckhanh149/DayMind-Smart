import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> icon(int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(size / 100);
  final paint = ui.Paint()..isAntiAlias = true;
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(0, 0, 100, 100),
      const ui.Radius.circular(24),
    ),
    paint..color = const ui.Color(0xff526b4b),
  );
  final leaf = ui.Path()
    ..moveTo(26, 70)
    ..cubicTo(9, 35, 46, 16, 80, 22)
    ..cubicTo(83, 59, 63, 83, 26, 70);
  canvas.drawPath(leaf, paint..color = const ui.Color(0xffe8f2d6));
  final vein = ui.Path()
    ..moveTo(21, 81)
    ..quadraticBezierTo(39, 54, 65, 37);
  canvas.drawPath(
    vein,
    paint
      ..color = const ui.Color(0xff526b4b)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = ui.StrokeCap.round,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generate original DayMind launcher artwork', () async {
    for (final entry in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      await File('android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png')
          .writeAsBytes(await icon(entry.value));
    }
    final images = <Uint8List>[];
    for (final size in [16, 32, 48, 256]) {
      images.add(await icon(size));
    }
    final header = ByteData(6 + 16 * images.length)
      ..setUint16(2, 1, Endian.little)
      ..setUint16(4, images.length, Endian.little);
    var offset = header.lengthInBytes;
    for (var i = 0; i < images.length; i++) {
      final size = [16, 32, 48, 256][i];
      final at = 6 + i * 16;
      header.setUint8(at, size == 256 ? 0 : size);
      header.setUint8(at + 1, size == 256 ? 0 : size);
      header.setUint16(at + 4, 1, Endian.little);
      header.setUint16(at + 6, 32, Endian.little);
      header.setUint32(at + 8, images[i].length, Endian.little);
      header.setUint32(at + 12, offset, Endian.little);
      offset += images[i].length;
    }
    final bytes = BytesBuilder()..add(header.buffer.asUint8List());
    for (final image in images) {
      bytes.add(image);
    }
    await File('windows/runner/resources/app_icon.ico')
        .writeAsBytes(bytes.takeBytes());
  });
}
