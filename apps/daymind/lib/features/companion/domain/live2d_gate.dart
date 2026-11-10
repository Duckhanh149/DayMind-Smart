import 'character_package.dart';

/// No runtime/remote flag can enable a renderer whose technical and licensing
/// gates have not passed. Future integration requires an explicit code release.
abstract final class Live2DGate {
  static const message =
      'Live2D chưa được bật: cần kiểm chứng Android/Windows và giấy phép SDK/model. '
      'Hãy dùng PNG/WebP, GIF hoặc ZIP DayMind; thư viện hiện có vẫn được giữ.';

  static void requireRasterFiles(Iterable<String> names) {
    if (names.any((name) {
      final lower = name.toLowerCase();
      return lower.endsWith('.model3.json') ||
          lower.endsWith('.model.json') ||
          lower.endsWith('.moc3') ||
          lower.endsWith('.moc');
    })) {
      throw const CharacterPackageFailure(message);
    }
  }
}
