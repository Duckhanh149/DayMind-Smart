import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';

import '../domain/character_package.dart';
import '../domain/companion.dart' show CompanionExpression;
import 'image_preflight.dart';
import 'safe_zip.dart';

class CharacterImportCancelled implements Exception {
  const CharacterImportCancelled();
  @override
  String toString() => 'Đã hủy nhập nhân vật.';
}

class CharacterBlueprint {
  CharacterBlueprint._(
    this.name,
    this.sourceHash,
    this.sourceFormat,
    this.probe,
    this.manifest,
    this.provenance,
    this.licenseBytes,
  );
  final String name, sourceHash, sourceFormat;
  final CharacterImageProbe probe;
  final CharacterManifest? manifest;
  final CharacterProvenance provenance;
  final Uint8List? licenseBytes;
  bool get simpleStatic =>
      manifest == null && probe.frameCount == 1 && sourceFormat != 'gif';
  bool get sprite => manifest?.kind == CharacterPackageKind.sprite;
  int get frameCount => sprite ? manifest!.frames.length : probe.frameCount;
  List<int> get durations => sprite
      ? [for (final f in manifest!.frames) f.durationMs]
      : probe.durationsMs;
  Map<String, CharacterMotion> get motions =>
      manifest?.effectiveMotions(frameCount) ??
      {'idle': CharacterMotion(List.generate(frameCount, (i) => i))};
  Map<CompanionExpression, String> get expressions =>
      manifest?.expressions ?? const {};

  static Future<CharacterBlueprint> inspect(
    Uint8List bytes,
    String format,
    String name, {
    CharacterProvenance? provenance,
  }) => Isolate.run(
    () => inspectSync(bytes, format, name, provenance: provenance),
  );
  static CharacterBlueprint inspectSync(
    Uint8List bytes,
    String format,
    String name, {
    CharacterProvenance? provenance,
  }) {
    final hash = sha256.convert(bytes).toString();
    CharacterManifest? manifest;
    Uint8List? license;
    Uint8List media = bytes;
    String mediaFormat = format;
    if (format == 'zip') {
      final files = CharacterZip.read(bytes).files;
      final root = files['manifest.json'];
      if (root == null) {
        throw const CharacterPackageFailure(
          'Gói cần manifest.json ở thư mục gốc.',
        );
      }
      manifest = CharacterManifest.fromJson(characterJson(root));
      manifest.validateFiles(files);
      media = files[manifest.image]!;
      mediaFormat = manifest.image.split('.').last.toLowerCase();
      if (manifest.licenseFile != null) license = files[manifest.licenseFile];
    } else if (!{'png', 'webp', 'gif'}.contains(format) ||
        bytes.length > CharacterImageProbe.maxBytes) {
      throw const CharacterPackageFailure(
        'Chỉ nhận PNG/WebP, GIF hoặc gói ZIP DayMind có giới hạn.',
      );
    }
    final probe = CharacterImageProbe.inspect(
      media,
      expectedFormat: mediaFormat,
    );
    if (manifest?.kind != CharacterPackageKind.animation &&
        manifest != null &&
        probe.frameCount != 1) {
      throw const CharacterPackageFailure(
        'Ảnh nền sprite hoặc ảnh tĩnh không được chứa hoạt ảnh.',
      );
    }
    if (manifest?.kind == CharacterPackageKind.animation &&
        (probe.width > 1024 || probe.height > 1024)) {
      throw const CharacterPackageFailure('Ảnh động tối đa 1024² pixel.');
    }
    if (manifest?.kind == CharacterPackageKind.sprite) {
      for (final f in manifest!.frames) {
        f.validateBounds(probe.width, probe.height);
      }
    }
    final label =
        manifest?.name ?? (name.length > 80 ? name.substring(0, 80) : name);
    final result = CharacterBlueprint._(
      label,
      hash,
      format,
      probe,
      manifest,
      manifest?.provenance ??
          provenance ??
          CharacterProvenance(license: 'Quyền sử dụng do người nhập xác nhận.'),
      license,
    );
    if (result.simpleStatic && bytes.length > 4 * 1024 * 1024) {
      throw const CharacterPackageFailure('Ảnh tĩnh tối đa 4 MiB.');
    }
    manifest?.validateFrameCount(
      result.frameCount,
      durations: result.durations,
    );
    for (final m in result.motions.values) {
      if (m.frames.any((i) => i >= result.frameCount) ||
          m.frames.fold<int>(0, (n, i) => n + result.durations[i]) > 60000) {
        throw const CharacterPackageFailure(
          'Chuyển động vượt 60 giây hoặc tham chiếu khung hình không tồn tại.',
        );
      }
    }
    return result;
  }
}

class PreparedCharacterAnimation {
  PreparedCharacterAnimation(
    this.metadata,
    Uint8List atlas,
    Uint8List preview,
    this.licenseBytes,
  ) : atlasBytes = atlas.asUnmodifiableView(),
      previewBytes = preview.asUnmodifiableView();
  final CharacterRenderData metadata;
  final Uint8List atlasBytes, previewBytes;
  final Uint8List? licenseBytes;
}

class CharacterNormalizer {
  static Future<PreparedCharacterAnimation> build(
    CharacterBlueprint source, {
    bool Function()? cancelled,
    void Function(int, int)? progress,
  }) async {
    void check() {
      if (cancelled?.call() == true) throw const CharacterImportCancelled();
    }

    check();
    final count = source.frameCount,
        columns = math.min(16, source.frameCount),
        width = math.min(16, source.frameCount) * 128,
        height = ((source.frameCount + 15) ~/ 16) * 128;
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      source.probe.decoderBytes,
    );
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    final owned = <ui.Image>[];
    final recorder = ui.PictureRecorder();
    ui.Picture? picture;
    ui.Image? atlasImage;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width != source.probe.width ||
          descriptor.height != source.probe.height) {
        throw const CharacterPackageFailure(
          'Kích thước ảnh nguồn không nhất quán.',
        );
      }
      final scale = source.sprite
          ? 1.0
          : 128 / math.max(descriptor.width, descriptor.height);
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      if (codec.frameCount != source.probe.frameCount) {
        throw const CharacterPackageFailure(
          'Số khung hình nguồn không nhất quán.',
        );
      }
      final canvas = ui.Canvas(recorder),
          frames = <SpriteFrame>[],
          durations = source.durations;
      final paint = ui.Paint()
        ..filterQuality = source.manifest?.sampling == 'nearest'
            ? ui.FilterQuality.none
            : ui.FilterQuality.medium;
      ui.Image? sheet;
      if (source.sprite) {
        sheet = (await codec.getNextFrame()).image;
        owned.add(sheet);
      }
      for (var i = 0; i < count; i++) {
        check();
        final image = sheet ?? (await codec.getNextFrame()).image;
        if (sheet == null) {
          owned.add(image);
          if (image.width > 128 || image.height > 128) {
            throw const CharacterPackageFailure(
              'Bộ giải mã vượt giới hạn texture hoạt ảnh.',
            );
          }
        }
        final rect = source.sprite
            ? ui.Rect.fromLTWH(
                source.manifest!.frames[i].x.toDouble(),
                source.manifest!.frames[i].y.toDouble(),
                source.manifest!.frames[i].width.toDouble(),
                source.manifest!.frames[i].height.toDouble(),
              )
            : ui.Rect.fromLTWH(
                0,
                0,
                image.width.toDouble(),
                image.height.toDouble(),
              );
        final tileX = (i % columns) * 128,
            tileY = (i ~/ columns) * 128,
            factor = math.min(128 / rect.width, 128 / rect.height),
            w = rect.width * factor,
            h = rect.height * factor;
        canvas.drawImageRect(
          image,
          rect,
          ui.Rect.fromLTWH(tileX + (128 - w) / 2, tileY + (128 - h) / 2, w, h),
          paint,
        );
        frames.add(SpriteFrame(tileX, tileY, 128, 128, durations[i]));
        progress?.call(i + 1, count);
        if (i % 4 == 3) await Future<void>.delayed(Duration.zero);
      }
      check();
      picture = recorder.endRecording();
      atlasImage = await picture.toImage(width, height);
      final atlas = await atlasImage.toByteData(format: ui.ImageByteFormat.png);
      check();
      if (atlas == null || atlas.lengthInBytes > 8 * 1024 * 1024) {
        throw const CharacterPackageFailure('Atlas hoạt ảnh vượt 8 MiB.');
      }
      final previewRecorder = ui.PictureRecorder();
      ui.Canvas(previewRecorder).drawImageRect(
        atlasImage,
        const ui.Rect.fromLTWH(0, 0, 128, 128),
        const ui.Rect.fromLTWH(0, 0, 128, 128),
        ui.Paint(),
      );
      final previewPicture = previewRecorder.endRecording();
      ui.Image? previewImage;
      Uint8List preview;
      try {
        previewImage = await previewPicture.toImage(128, 128);
        final data = await previewImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) {
          throw const CharacterPackageFailure('Chưa tạo được ảnh xem trước.');
        }
        preview = data.buffer.asUint8List();
      } finally {
        previewImage?.dispose();
        previewPicture.dispose();
      }
      final atlasBytes = atlas.buffer.asUint8List();
      final meta = CharacterRenderData.fromJson({
        'schema': 1,
        'name': source.name,
        'sourceHash': source.sourceHash,
        'sourceFormat': source.sourceFormat,
        'width': width,
        'height': height,
        'frames': [for (final f in frames) f.toJson()],
        'motions': {
          for (final e in source.motions.entries) e.key: e.value.toJson(),
        },
        'expressions': {
          for (final e in source.expressions.entries) e.key.name: e.value,
        },
        'provenance': source.provenance.toJson(),
        'atlasHash': sha256.convert(atlasBytes).toString(),
        'previewHash': sha256.convert(preview).toString(),
        'hasLicenseText': source.licenseBytes != null,
      });
      check();
      return PreparedCharacterAnimation(
        meta,
        atlasBytes,
        preview,
        source.licenseBytes,
      );
    } finally {
      if (recorder.isRecording) recorder.endRecording().dispose();
      picture?.dispose();
      atlasImage?.dispose();
      for (final image in owned) {
        image.dispose();
      }
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
