import 'dart:typed_data';
import 'dart:isolate';

Future<Uint8List> cutFlatBackgroundAsync(
  Uint8List bytes,
  int width,
  int height,
) => Isolate.run(() => cutFlatBackground(bytes, width, height));

/// Removes only edge-connected flat color. Enclosed regions of that color
/// remain intact. Input is a bounded, downscaled straight-RGBA preview.
Uint8List cutFlatBackground(Uint8List rgba, int width, int height) {
  if (width < 1 ||
      height < 1 ||
      width > 256 ||
      height > 256 ||
      rgba.length != width * height * 4) {
    throw const FormatException('Ảnh xem trước không hợp lệ.');
  }
  final out = Uint8List.fromList(rgba);
  final corners = [0, width - 1, (height - 1) * width, width * height - 1];
  final opaque = corners.where((p) => rgba[p * 4 + 3] > 240).toList();
  bool similar(int p, int reference) {
    for (var c = 0; c < 3; c++) {
      if ((rgba[p * 4 + c] - rgba[reference * 4 + c]).abs() > 24) return false;
    }
    return true;
  }

  if (opaque.isNotEmpty && opaque.any((p) => !similar(p, opaque.first))) {
    throw const FormatException(
      'Nền nhiều màu chưa tách tự động được. Hãy dùng PNG nền trong suốt.',
    );
  }
  final visited = Uint8List(width * height), queue = <int>[];
  void add(int p) {
    if (visited[p] != 0) return;
    visited[p] = 1;
    if (rgba[p * 4 + 3] < 8 ||
        (opaque.isNotEmpty && similar(p, opaque.first))) {
      queue.add(p);
    }
  }

  for (var x = 0; x < width; x++) {
    add(x);
    add((height - 1) * width + x);
  }
  for (var y = 0; y < height; y++) {
    add(y * width);
    add(y * width + width - 1);
  }
  for (var i = 0; i < queue.length; i++) {
    final p = queue[i], x = p % width, y = p ~/ width;
    out[p * 4 + 3] = 0;
    if (x > 0) add(p - 1);
    if (x + 1 < width) add(p + 1);
    if (y > 0) add(p - width);
    if (y + 1 < height) add(p + width);
  }
  return out;
}
