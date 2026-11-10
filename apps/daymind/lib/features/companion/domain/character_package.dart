import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'companion.dart' show CompanionExpression;

class CharacterPackageFailure implements Exception {
  const CharacterPackageFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

Never _invalid([String message = 'Manifest gói nhân vật không hợp lệ.']) =>
    throw CharacterPackageFailure(message);

Map<String, dynamic> _object(
  Object? value,
  Set<String> allowed, [
  Set<String> required = const {},
]) {
  if (value is! Map ||
      value.keys.any((k) => k is! String || !allowed.contains(k)) ||
      !required.every(value.containsKey)) {
    _invalid();
  }
  return value.cast<String, dynamic>();
}

int _integer(Object? value, int low, int high) {
  if (value is! int || value < low || value > high) _invalid();
  return value;
}

String _text(
  Object? value,
  int max, {
  bool required = true,
  bool multiline = false,
}) {
  if (value is! String ||
      value.length > max ||
      (required && value.trim().isEmpty) ||
      RegExp(
        multiline ? r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]' : r'[\x00-\x1f\x7f]',
      ).hasMatch(value)) {
    _invalid();
  }
  return value;
}

String characterPackagePath(Object? value) {
  final path = _text(value, 200), parts = path.split('/');
  if (parts.length > 4 ||
      parts.any(
        (p) =>
            p.isEmpty ||
            p == '.' ||
            p == '..' ||
            p.endsWith('.') ||
            !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(p) ||
            RegExp(
              r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\.|$)',
              caseSensitive: false,
            ).hasMatch(p),
      )) {
    _invalid('Đường dẫn trong manifest không an toàn hoặc chưa được hỗ trợ.');
  }
  return path;
}

Map<String, dynamic> characterJson(Uint8List bytes) {
  if (bytes.length > 65536) _invalid('Manifest tối đa 64 KiB.');
  try {
    final value = utf8.decode(bytes);
    var depth = 0, quoted = false, escaped = false;
    for (final c in value.codeUnits) {
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (c == 92) {
          escaped = true;
        } else if (c == 34) {
          quoted = false;
        }
      } else if (c == 34) {
        quoted = true;
      } else if (c == 123 || c == 91) {
        if (++depth > 12) _invalid();
      } else if (c == 125 || c == 93) {
        if (--depth < 0) _invalid();
      }
    }
    if (depth != 0 || quoted) _invalid();
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) _invalid();
    return decoded;
  } on CharacterPackageFailure {
    rethrow;
  } catch (_) {
    _invalid('Manifest cần là JSON UTF-8 hợp lệ.');
  }
}

class CharacterProvenance {
  CharacterProvenance({
    this.author = '',
    required this.license,
    this.source = '',
  }) {
    _text(author, 80, required: false);
    _text(license, 500, multiline: true);
    _text(source, 300, required: false);
  }
  final String author, license, source;
  factory CharacterProvenance.fromJson(Object? value) {
    final j = _object(value, {'author', 'license', 'source'}, {'license'});
    return CharacterProvenance(
      author: _text(j['author'] ?? '', 80, required: false),
      license: _text(j['license'], 500, multiline: true),
      source: _text(j['source'] ?? '', 300, required: false),
    );
  }
  Map<String, dynamic> toJson() => {
    'author': author,
    'license': license,
    'source': source,
  };
}

class SpriteFrame {
  const SpriteFrame(this.x, this.y, this.width, this.height, this.durationMs);
  final int x, y, width, height, durationMs;
  factory SpriteFrame.fromJson(Object? value) {
    final j = _object(
      value,
      {'x', 'y', 'width', 'height', 'durationMs'},
      {'x', 'y', 'width', 'height', 'durationMs'},
    );
    return SpriteFrame(
      _integer(j['x'], 0, 2048),
      _integer(j['y'], 0, 2048),
      _integer(j['width'], 1, 2048),
      _integer(j['height'], 1, 2048),
      _integer(j['durationMs'], 1, 5000).clamp(84, 5000),
    );
  }
  void validateBounds(int imageWidth, int imageHeight) {
    if (x < 0 ||
        y < 0 ||
        width < 1 ||
        height < 1 ||
        x + width > imageWidth ||
        y + height > imageHeight) {
      _invalid('Khung sprite nằm ngoài ảnh nguồn.');
    }
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'durationMs': durationMs,
  };
}

class CharacterMotion {
  CharacterMotion(List<int> frames, {this.loop = true})
    : frames = List.unmodifiable(frames) {
    if (frames.isEmpty ||
        frames.length > 120 ||
        frames.any((i) => i < 0 || i >= 120)) {
      _invalid();
    }
  }
  final List<int> frames;
  final bool loop;
  factory CharacterMotion.fromJson(Object? value) {
    final j = _object(value, {'frames', 'loop'}, {'frames'}), raw = j['frames'];
    if (raw is! List || (j['loop'] != null && j['loop'] is! bool)) _invalid();
    return CharacterMotion([
      for (final f in raw) _integer(f, 0, 119),
    ], loop: j['loop'] as bool? ?? true);
  }
  Map<String, dynamic> toJson() => {'frames': frames, 'loop': loop};
}

enum CharacterPackageKind { staticImage, sprite, animation }

class CharacterManifest {
  CharacterManifest._(
    this.name,
    this.kind,
    this.image,
    this.frames,
    this.motions,
    this.expressions,
    this.provenance,
    this.checksums,
    this.sampling,
    this.licenseFile,
  );
  final String name, image, sampling;
  final String? licenseFile;
  final CharacterPackageKind kind;
  final List<SpriteFrame> frames;
  final Map<String, CharacterMotion> motions;
  final Map<CompanionExpression, String> expressions;
  final CharacterProvenance provenance;
  final Map<String, String> checksums;
  factory CharacterManifest.fromJson(Map<String, dynamic> j) {
    _object(
      j,
      {
        'format',
        'version',
        'name',
        'kind',
        'image',
        'frames',
        'motions',
        'expressions',
        'provenance',
        'checksums',
        'sampling',
        'licenseFile',
      },
      {'format', 'version', 'name', 'kind', 'image', 'provenance', 'checksums'},
    );
    if (j['format'] != 'daymind.character' ||
        _integer(j['version'], 1, 1) != 1) {
      _invalid();
    }
    final kind = switch (j['kind']) {
      'static' => CharacterPackageKind.staticImage,
      'sprite' => CharacterPackageKind.sprite,
      'animation' => CharacterPackageKind.animation,
      _ => _invalid('Kiểu gói chưa được hỗ trợ. Live2D vẫn tắt.'),
    };
    final name = _text(j['name'], 80), image = characterPackagePath(j['image']);
    final ext = image.split('.').last.toLowerCase();
    if (kind == CharacterPackageKind.animation
        ? !{'gif', 'webp'}.contains(ext)
        : !{'png', 'webp'}.contains(ext)) {
      _invalid();
    }
    final rawFrames = j['frames'] ?? const [];
    if (rawFrames is! List ||
        rawFrames.length > 120 ||
        (kind == CharacterPackageKind.sprite
            ? rawFrames.isEmpty
            : rawFrames.isNotEmpty)) {
      _invalid();
    }
    final frames = List<SpriteFrame>.unmodifiable(
      rawFrames.map(SpriteFrame.fromJson),
    );
    final rawMotions = j['motions'] ?? const {};
    if (rawMotions is! Map ||
        rawMotions.length > 16 ||
        rawMotions.keys.any(
          (k) =>
              k is! String || !RegExp(r'^[a-z][a-z0-9_-]{0,31}$').hasMatch(k),
        )) {
      _invalid();
    }
    final motions = Map<String, CharacterMotion>.unmodifiable({
      for (final e in rawMotions.entries)
        e.key as String: CharacterMotion.fromJson(e.value),
    });
    final rawExpressions = j['expressions'] ?? const {};
    if (rawExpressions is! Map || rawExpressions.length > 4) _invalid();
    final expressions = <CompanionExpression, String>{};
    for (final e in rawExpressions.entries) {
      final matches = CompanionExpression.values.where((v) => v.name == e.key);
      if (matches.length != 1 ||
          e.value is! String ||
          (motions.isEmpty
              ? e.value != 'idle'
              : !motions.containsKey(e.value))) {
        _invalid();
      }
      expressions[matches.single] = e.value as String;
    }
    final sampling =
        j['sampling'] ??
        (kind == CharacterPackageKind.sprite ? 'nearest' : 'smooth');
    if (sampling != 'nearest' && sampling != 'smooth') _invalid();
    final license = j['licenseFile'] == null
        ? null
        : characterPackagePath(j['licenseFile']);
    if (license != null && !license.toLowerCase().endsWith('.txt')) _invalid();
    final rawChecksums = j['checksums'];
    if (rawChecksums is! Map ||
        rawChecksums.length != (license == null ? 1 : 2) ||
        !rawChecksums.containsKey(image) ||
        (license != null && !rawChecksums.containsKey(license))) {
      _invalid();
    }
    final checksums = <String, String>{};
    for (final e in rawChecksums.entries) {
      if (e.key is! String ||
          e.value is! String ||
          !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(e.value as String)) {
        _invalid();
      }
      checksums[e.key as String] = (e.value as String).toLowerCase();
    }
    final result = CharacterManifest._(
      name,
      kind,
      image,
      frames,
      motions,
      Map.unmodifiable(expressions),
      CharacterProvenance.fromJson(j['provenance']),
      Map.unmodifiable(checksums),
      sampling as String,
      license,
    );
    if (kind != CharacterPackageKind.animation) {
      result.validateFrameCount(
        kind == CharacterPackageKind.sprite ? frames.length : 1,
      );
    }
    return result;
  }
  void validateFrameCount(int count, {List<int>? durations}) {
    if (durations != null &&
        (durations.length != count ||
            durations.any((d) => d < 84 || d > 5000))) {
      _invalid();
    }
    if (count < 1 || count > 120) _invalid('Hoạt ảnh tối đa 120 khung hình.');
    for (final motion in effectiveMotions(count).values) {
      if (motion.frames.any((i) => i >= count)) {
        _invalid('Hoạt ảnh tham chiếu khung hình không tồn tại.');
      }
      if (durations != null &&
          motion.frames.fold<int>(0, (n, i) => n + durations[i]) > 60000) {
        _invalid('Mỗi chuyển động tối đa 60 giây.');
      }
    }
  }

  Map<String, CharacterMotion> effectiveMotions(int count) => motions.isEmpty
      ? {'idle': CharacterMotion(List.generate(count, (i) => i))}
      : motions;
  void validateFiles(Map<String, Uint8List> files) {
    final expected = {'manifest.json', image, ?licenseFile};
    if (files.length != expected.length || !expected.every(files.containsKey)) {
      _invalid(
        'Gói chỉ được chứa manifest và các ảnh/giấy phép đã khai báo; không nhận mã hoặc tệp khác.',
      );
    }
    for (final entry in checksums.entries) {
      final bytes = files[entry.key]!;
      if (bytes.length > (entry.key == licenseFile ? 65536 : 8 * 1024 * 1024) ||
          sha256.convert(bytes).toString() != entry.value) {
        _invalid('Tệp trong gói không khớp SHA256 hoặc vượt dung lượng.');
      }
    }
    if (licenseFile != null) {
      try {
        utf8.decode(files[licenseFile]!);
      } catch (_) {
        _invalid('Giấy phép cần là văn bản UTF-8.');
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'format': 'daymind.character',
    'version': 1,
    'name': name,
    'kind': switch (kind) {
      CharacterPackageKind.staticImage => 'static',
      CharacterPackageKind.sprite => 'sprite',
      CharacterPackageKind.animation => 'animation',
    },
    'image': image,
    'frames': [for (final f in frames) f.toJson()],
    'motions': {for (final e in motions.entries) e.key: e.value.toJson()},
    'expressions': {for (final e in expressions.entries) e.key.name: e.value},
    'provenance': provenance.toJson(),
    'checksums': checksums,
    'sampling': sampling,
    if (licenseFile != null) 'licenseFile': licenseFile,
  };
}

/// Installed render metadata. Filenames are fixed by the installer, not supplied
/// by this JSON. Coordinates always address a canonical 128px tile atlas.
class CharacterRenderData {
  CharacterRenderData._(
    this.name,
    this.sourceHash,
    this.sourceFormat,
    this.width,
    this.height,
    this.frames,
    this.motions,
    this.expressions,
    this.provenance,
    this.atlasHash,
    this.previewHash,
    this.hasLicenseText,
  );
  final String name, sourceHash, sourceFormat, atlasHash, previewHash;
  final int width, height;
  final List<SpriteFrame> frames;
  final Map<String, CharacterMotion> motions;
  final Map<CompanionExpression, String> expressions;
  final CharacterProvenance provenance;
  final bool hasLicenseText;
  static const tileSize = 128, maxColumns = 16;
  factory CharacterRenderData.fromJson(Map<String, dynamic> j) {
    _object(
      j,
      {
        'schema',
        'name',
        'sourceHash',
        'sourceFormat',
        'width',
        'height',
        'frames',
        'motions',
        'expressions',
        'provenance',
        'atlasHash',
        'previewHash',
        'hasLicenseText',
      },
      {
        'schema',
        'name',
        'sourceHash',
        'sourceFormat',
        'width',
        'height',
        'frames',
        'motions',
        'expressions',
        'provenance',
        'atlasHash',
        'previewHash',
        'hasLicenseText',
      },
    );
    _integer(j['schema'], 1, 1);
    String hash(Object? value) {
      final s = _text(value, 64);
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(s)) _invalid();
      return s;
    }

    final format = _text(j['sourceFormat'], 8);
    if (!{'png', 'gif', 'webp', 'zip'}.contains(format) ||
        j['hasLicenseText'] is! bool) {
      _invalid();
    }
    final rawFrames = j['frames'];
    if (rawFrames is! List || rawFrames.isEmpty || rawFrames.length > 120) {
      _invalid();
    }
    final frames = List<SpriteFrame>.unmodifiable(
      rawFrames.map(SpriteFrame.fromJson),
    );
    final columns = frames.length < maxColumns ? frames.length : maxColumns,
        width = _integer(j['width'], 128, 2048),
        height = _integer(j['height'], 128, 1024);
    if (width != columns * tileSize ||
        height != ((frames.length + columns - 1) ~/ columns) * tileSize) {
      _invalid();
    }
    for (var i = 0; i < frames.length; i++) {
      final f = frames[i];
      if (f.x != (i % columns) * tileSize ||
          f.y != (i ~/ columns) * tileSize ||
          f.width != tileSize ||
          f.height != tileSize ||
          f.durationMs != (rawFrames[i] as Map)['durationMs']) {
        _invalid();
      }
    }
    final rawMotions = j['motions'];
    if (rawMotions is! Map ||
        rawMotions.isEmpty ||
        rawMotions.length > 16 ||
        rawMotions.keys.any(
          (k) =>
              k is! String || !RegExp(r'^[a-z][a-z0-9_-]{0,31}$').hasMatch(k),
        )) {
      _invalid();
    }
    final motions = Map<String, CharacterMotion>.unmodifiable({
      for (final e in rawMotions.entries)
        e.key as String: CharacterMotion.fromJson(e.value),
    });
    for (final m in motions.values) {
      if (m.frames.any((i) => i >= frames.length) ||
          m.frames.fold<int>(0, (n, i) => n + frames[i].durationMs) > 60000) {
        _invalid();
      }
    }
    final rawExpressions = j['expressions'];
    if (rawExpressions is! Map || rawExpressions.length > 4) _invalid();
    final expressions = <CompanionExpression, String>{};
    for (final e in rawExpressions.entries) {
      final found = CompanionExpression.values.where((v) => v.name == e.key);
      if (found.length != 1 ||
          e.value is! String ||
          !motions.containsKey(e.value)) {
        _invalid();
      }
      expressions[found.single] = e.value as String;
    }
    return CharacterRenderData._(
      _text(j['name'], 80),
      hash(j['sourceHash']),
      format,
      width,
      height,
      frames,
      motions,
      Map.unmodifiable(expressions),
      CharacterProvenance.fromJson(j['provenance']),
      hash(j['atlasHash']),
      hash(j['previewHash']),
      j['hasLicenseText'] as bool,
    );
  }
  String motionName(CompanionExpression expression) =>
      expressions[expression] ??
      expressions[CompanionExpression.neutral] ??
      (motions.containsKey('idle') ? 'idle' : motions.keys.first);
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'name': name,
    'sourceHash': sourceHash,
    'sourceFormat': sourceFormat,
    'width': width,
    'height': height,
    'frames': [for (final f in frames) f.toJson()],
    'motions': {for (final e in motions.entries) e.key: e.value.toJson()},
    'expressions': {for (final e in expressions.entries) e.key.name: e.value},
    'provenance': provenance.toJson(),
    'atlasHash': atlasHash,
    'previewHash': previewHash,
    'hasLicenseText': hasLicenseText,
  };
}
