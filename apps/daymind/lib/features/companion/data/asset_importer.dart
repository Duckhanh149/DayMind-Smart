import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../tasks/domain/task.dart';
import '../domain/character_package.dart';
import '../domain/companion.dart' show isCharacterAssetName;
import '../domain/live2d_gate.dart';
import 'character_preparer.dart';
import 'image_preflight.dart';

class StaticAssetPreview {
  StaticAssetPreview._(Uint8List source, Uint8List preview, this.fileName)
    : _source = source.asUnmodifiableView(),
      bytes = preview.asUnmodifiableView(),
      animation = null;
  StaticAssetPreview._package(
    Uint8List source,
    PreparedCharacterAnimation prepared,
    this.fileName,
  ) : _source = source.asUnmodifiableView(),
      bytes = prepared.previewBytes,
      animation = prepared;
  final PreparedCharacterAnimation? animation;
  final Uint8List _source;
  final Uint8List bytes;
  final String fileName;
}

class InstalledCharacter {
  const InstalledCharacter(
    this.metadata,
    this.atlas,
    this.preview,
    this.source,
  );
  final CharacterRenderData metadata;
  final File atlas, preview, source;
}

class StaticAssetImporter {
  StaticAssetImporter(this.directory);
  final Directory directory;
  static const maxBytes = 4 * 1024 * 1024;
  static const maxDimension = 2048;
  static const maxFiles = 128;
  static const maxLibraryBytes = 32 * 1024 * 1024;
  Future<void> _tail = Future.value();
  int _pendingImports = 0;
  int _pendingPreparations = 0;
  int revision = 0;
  final _renderJobs = <String, Future<File?>>{};
  final _characters = <String, Future<InstalledCharacter?>>{};
  final _reads = <Future<void>>{};
  bool _closed = false;
  void _checkOpen() {
    if (_closed) throw const CharacterImportCancelled();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _renderJobs.clear();
    _characters.clear();
    revision++;
  }

  Future<void> drain() async {
    close();
    await _tail;
    await Future.wait(_reads.toList());
  }

  Future<T> _trackRead<T>(Future<T> result) {
    late final Future<void> tracked;
    tracked = result
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() => _reads.remove(tracked));
    _reads.add(tracked);
    return result;
  }

  void resume() {
    _closed = false;
    revision++;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    if (_closed) return Future.error(const CharacterImportCancelled());
    final next = _tail.then((_) {
      _checkOpen();
      return action();
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  static String validateSignature(Uint8List bytes, String name) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const ValidationException('Ảnh cần nhỏ hơn hoặc bằng 4 MB.');
    }
    if (p.basename(name) != name ||
        name.contains('..') ||
        name.contains('\\')) {
      throw const ValidationException('Tên tệp không hợp lệ.');
    }
    final ext = p.extension(name).toLowerCase();
    final png =
        bytes.length >= 24 &&
        [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ].asMap().entries.every((e) => bytes[e.key] == e.value);
    final webp =
        bytes.length >= 16 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    if (ext == '.png' && png) {
      return 'png';
    }
    if (ext == '.webp' && webp) {
      return 'webp';
    }
    throw const ValidationException(
      'Chỉ nhận PNG hoặc WebP tĩnh đúng định dạng. ZIP, GIF và Live2D chưa được hỗ trợ.',
    );
  }

  Future<StaticAssetPreview> prepare(File source, String displayName) async {
    final bytes = await _readSource(source);
    validateSignature(bytes, displayName);
    final preview = await _serialized(() => _validateImage(bytes));
    return StaticAssetPreview._(bytes, preview, displayName);
  }

  Future<StaticAssetPreview> prepareCharacter(
    File source,
    String displayName, {
    bool Function()? cancelled,
    void Function(int, int)? progress,
  }) {
    if (_closed) return Future.error(const CharacterImportCancelled());
    if (_pendingPreparations >= 2) {
      return Future.error(
        const ValidationException(
          'Đang chuẩn bị nhân vật. Hãy chờ hoặc hủy lượt hiện tại.',
        ),
      );
    }
    _pendingPreparations++;
    return _trackRead(
      _prepareCharacter(
        source,
        displayName,
        cancelled: cancelled,
        progress: progress,
      ).whenComplete(() => _pendingPreparations--),
    );
  }

  Future<StaticAssetPreview> _prepareCharacter(
    File source,
    String displayName, {
    bool Function()? cancelled,
    void Function(int, int)? progress,
  }) async {
    _checkOpen();
    Live2DGate.requireRasterFiles([displayName]);
    final format = p.extension(displayName).toLowerCase().replaceFirst('.', '');
    if (!{'png', 'webp', 'gif', 'zip'}.contains(format) ||
        p.basename(displayName) != displayName ||
        displayName.contains('..') ||
        displayName.contains('\\')) {
      throw const ValidationException(
        'Hãy chọn PNG/WebP, GIF hoặc ZIP DayMind đúng định dạng.',
      );
    }
    final bytes = await _readSource(
      source,
      limit: format == 'zip'
          ? 16 * 1024 * 1024
          : format == 'png'
          ? maxBytes
          : CharacterImageProbe.maxBytes,
    );
    final blueprint = await CharacterBlueprint.inspect(
      bytes,
      format,
      p.basenameWithoutExtension(displayName),
    );
    _checkOpen();
    if (cancelled?.call() == true) throw const CharacterImportCancelled();
    if (blueprint.simpleStatic) {
      final preview = await _serialized(
        () => _validateImage(blueprint.probe.decoderBytes),
      );
      return StaticAssetPreview._(bytes, preview, displayName);
    }
    final animation = await _serialized(
      () => CharacterNormalizer.build(
        blueprint,
        cancelled: () => _closed || cancelled?.call() == true,
        progress: progress,
      ),
    );
    return StaticAssetPreview._package(bytes, animation, displayName);
  }

  Future<String> installPrepared(
    StaticAssetPreview preview, {
    bool rightsConfirmed = false,
  }) => _serialized(() async {
    if (preview.animation == null) {
      return _installBytes(
        preview._source,
        preview.fileName,
        preview: preview.bytes,
      );
    }
    if (!rightsConfirmed) {
      throw const ValidationException(
        'Hãy xác nhận bạn có quyền sử dụng gói nhân vật.',
      );
    }
    return _installPackage(preview);
  });
  Future<String> install(File source, String displayName) async =>
      installBytes(await _readSource(source), displayName);
  Future<Uint8List> _readSource(File source, {int limit = maxBytes}) async {
    _checkOpen();
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const ValidationException(
        'Hãy chọn tệp ảnh thường, không phải liên kết.',
      );
    }
    if (await source.length() > limit) {
      throw const ValidationException('Tệp vượt dung lượng cho phép.');
    }
    final content = BytesBuilder(copy: false);
    await for (final chunk in source.openRead(0, limit + 1)) {
      content.add(chunk);
    }
    _checkOpen();
    if (content.length > limit) {
      throw const ValidationException('Tệp vượt dung lượng cho phép.');
    }
    return content.takeBytes();
  }

  Future<String> installBytes(Uint8List bytes, String displayName) async {
    validateSignature(bytes, displayName);
    if (_pendingImports >= 4) {
      throw const ValidationException(
        'Đang nhập ảnh. Hãy chờ lượt hiện tại hoàn tất.',
      );
    }
    _pendingImports++;
    // A caller may reuse its buffer while a previous decode is queued.
    final owned = Uint8List.fromList(bytes);
    try {
      return await _serialized(() => _installBytes(owned, displayName));
    } finally {
      _pendingImports--;
    }
  }

  Future<String> _installBytes(
    Uint8List bytes,
    String displayName, {
    Uint8List? preview,
  }) async {
    final ext = validateSignature(bytes, displayName);
    await _ensureRoot();
    final name = '${sha256.convert(bytes)}.$ext';
    final destination = File(p.join(directory.path, name));
    final type = await FileSystemEntity.type(
      destination.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      throw const ValidationException(
        'Ảnh trong thư viện không được là liên kết.',
      );
    }
    if (type == FileSystemEntityType.file) {
      return name;
    }
    final thumb = preview ?? await _validateImage(bytes);
    final usage = await _usage();
    if (usage.$2 >= maxFiles ||
        usage.$1 + bytes.length + thumb.length > maxLibraryBytes) {
      throw const ValidationException(
        'Thư viện tối đa 128 ảnh và 32 MB, gồm ảnh xem trước. Hãy dọn ảnh không còn dùng.',
      );
    }
    final thumbnail = _thumbnail(name);
    await thumbnail.parent.create(recursive: true);
    // The source is the installed record; a crash before the derivative commits
    // leaves a valid source whose preview can be rebuilt lazily.
    await _atomicWrite(destination, bytes);
    try {
      await _atomicWrite(thumbnail, thumb);
    } catch (_) {
      await destination.delete();
      rethrow;
    }
    revision++;
    return name;
  }

  Future<Uint8List> _validateImage(Uint8List bytes) async {
    final probe = CharacterImageProbe.inspect(bytes);
    if (probe.frameCount != 1) {
      throw const ValidationException(
        'Hãy dùng luồng nhập hoạt ảnh cho GIF/WebP động.',
      );
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(probe.decoderBytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width > maxDimension || descriptor.height > maxDimension) {
        throw const ValidationException('Ảnh tối đa 2048 × 2048 pixel.');
      }
      final scale = math.min(
        1.0,
        256 / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      if (codec.frameCount != 1) {
        throw const ValidationException(
          'Hãy chọn ảnh tĩnh; ảnh động sẽ được hỗ trợ ở giai đoạn sau.',
        );
      }
      final frame = await codec.getNextFrame();
      try {
        final encoded = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (encoded == null) {
          throw const ValidationException('Chưa tạo được ảnh xem trước.');
        }
        return encoded.buffer.asUint8List();
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<(int, int)> _usage() async {
    var bytes = 0, originals = 0;
    await for (final entry in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is File) {
        bytes += await entry.length();
        if (p.equals(entry.parent.path, directory.path)) originals++;
      } else if (entry is Directory &&
          p.equals(entry.parent.path, directory.path) &&
          _packName(p.basename(entry.path))) {
        originals++;
      }
    }
    return (bytes, originals);
  }

  File _thumbnail(String name) {
    if (_packName(name)) {
      final root = _packageDirectory(name);
      if (root == null) {
        throw const ValidationException('Gói nhân vật không hợp lệ.');
      }
      final file = File(p.join(root.path, 'preview.png'));
      if (FileSystemEntity.typeSync(file.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const ValidationException(
          'Ảnh xem trước không được là liên kết.',
        );
      }
      return file;
    }
    final folder = p.join(directory.path, '.previews');
    if (FileSystemEntity.typeSync(folder, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const ValidationException(
        'Thư mục ảnh xem trước không được là liên kết.',
      );
    }
    final result = File(p.join(folder, '$name.png'));
    if (FileSystemEntity.typeSync(result.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const ValidationException('Ảnh xem trước không được là liên kết.');
    }
    return result;
  }

  Future<void> _atomicWrite(File destination, Uint8List bytes) async {
    final staging = File(
      p.join(destination.parent.path, '${const Uuid().v4()}.tmp'),
    );
    try {
      _checkOpen();
      await staging.writeAsBytes(bytes, flush: true);
      _checkOpen();
      await staging.rename(destination.path);
    } finally {
      if (await staging.exists()) await staging.delete();
    }
  }

  Future<File?> renderFile(String? name) {
    if (_closed) return Future.value(null);
    final source = resolve(name);
    if (source == null || !source.existsSync()) return Future.value(null);
    try {
      final thumbnail = _thumbnail(name!);
      if (thumbnail.existsSync()) return Future.value(thumbnail);
      if (_packName(name)) {
        throw const ValidationException(
          'Ảnh xem trước của gói bị thiếu. Nguồn gốc vẫn được giữ.',
        );
      }
    } catch (error, stack) {
      return Future.error(error, stack);
    }
    return _renderJobs.putIfAbsent(
      name,
      () => _serialized(() async {
        final thumbnail = _thumbnail(name);
        if (thumbnail.existsSync()) return thumbnail;
        final bytes = await _readSource(source);
        validateSignature(bytes, name);
        final preview = await _validateImage(bytes);
        if ((await _usage()).$1 + preview.length > maxLibraryBytes) {
          throw const ValidationException(
            'Hãy dọn thư viện để tạo ảnh xem trước.',
          );
        }
        await thumbnail.parent.create(recursive: true);
        await _atomicWrite(thumbnail, preview);
        return thumbnail;
      }),
    );
  }

  static bool _packName(String name) =>
      isCharacterAssetName(name) && name.endsWith('.character');
  Directory? _packageDirectory(String name) {
    if (!_packName(name) ||
        FileSystemEntity.typeSync(directory.path, followLinks: false) ==
            FileSystemEntityType.link) {
      return null;
    }
    final path = p.join(directory.path, name);
    return FileSystemEntity.typeSync(path, followLinks: false) ==
            FileSystemEntityType.directory
        ? Directory(path)
        : null;
  }

  Future<void> _ensureRoot() async {
    _checkOpen();
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw const ValidationException(
        'Thư viện cần là thư mục thường, không phải liên kết.',
      );
    }
    _checkOpen();
    await directory.create(recursive: true);
  }

  Future<String> _installPackage(StaticAssetPreview preview) async {
    final prepared = preview.animation!,
        meta = prepared.metadata,
        name = '${meta.sourceHash}.character';
    await _ensureRoot();
    final destination = Directory(p.join(directory.path, name));
    final type = await FileSystemEntity.type(
      destination.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.directory) {
      if (await character(name) == null) {
        throw const ValidationException(
          'Gói cũ bị thiếu dữ liệu; chưa ghi đè.',
        );
      }
      return name;
    }
    if (type != FileSystemEntityType.notFound) {
      throw const ValidationException(
        'Mã gói trùng với dữ liệu khác; chưa ghi đè.',
      );
    }
    final metadata = Uint8List.fromList(utf8.encode(jsonEncode(meta.toJson())));
    final usage = await _usage(),
        total =
            preview._source.length +
            prepared.atlasBytes.length +
            prepared.previewBytes.length +
            metadata.length +
            (prepared.licenseBytes?.length ?? 0);
    if (usage.$2 >= maxFiles || usage.$1 + total > maxLibraryBytes) {
      throw const ValidationException(
        'Thư viện tối đa 128 mục/32 MiB, gồm nguồn và atlas. Hãy dọn mục không còn dùng.',
      );
    }
    final stage = Directory(
      p.join(directory.path, '.install-${const Uuid().v4()}'),
    );
    try {
      _checkOpen();
      await stage.create();
      for (final entry in <String, Uint8List>{
        'source.bin': preview._source,
        'atlas.png': prepared.atlasBytes,
        'preview.png': prepared.previewBytes,
        'asset.json': metadata,
        if (prepared.licenseBytes != null)
          'license.txt': prepared.licenseBytes!,
      }.entries) {
        _checkOpen();
        await File(p.join(stage.path, entry.key))
            .writeAsBytes(entry.value, flush: true);
      }
      _checkOpen();
      await stage.rename(destination.path);
      _characters.remove(name);
      revision++;
      return name;
    } finally {
      if (await stage.exists()) await stage.delete(recursive: true);
    }
  }

  Future<InstalledCharacter?> character(String? name) {
    if (_closed || name == null || _packageDirectory(name) == null) {
      return Future.value(null);
    }
    return _characters.putIfAbsent(name, () {
      return _trackRead(_loadCharacter(name));
    });
  }

  /// Cached metadata never authorizes an unbounded later read. Tracking the
  /// file handle also lets workspace deletion wait for all readers to close.
  Future<Uint8List> atlasBytes(InstalledCharacter character) =>
      _trackRead(_atlasBytes(character));

  Future<Uint8List> _atlasBytes(InstalledCharacter character) async {
    final bytes = await _readSource(character.atlas, limit: 8 * 1024 * 1024);
    final meta = character.metadata;
    await Isolate.run(() {
      final probe = CharacterImageProbe.inspect(bytes, expectedFormat: 'png');
      if (probe.frameCount != 1 ||
          probe.width != meta.width ||
          probe.height != meta.height ||
          sha256.convert(bytes).toString() != meta.atlasHash) {
        throw const ValidationException(
          'Atlas đã thay đổi; hãy nhập lại gói nhân vật.',
        );
      }
    });
    _checkOpen();
    return bytes;
  }

  Future<InstalledCharacter> _loadCharacter(String name) async {
    final root = _packageDirectory(name)!;
    final metaBytes = await _readSource(
          File(p.join(root.path, 'asset.json')),
          limit: 65536,
        ),
        source = resolve(name);
    if (source == null) {
      throw const ValidationException(
        'Gói nhân vật bị thiếu nguồn; chưa ghi đè dữ liệu.',
      );
    }
    final raw = await _readSource(source, limit: 16 * 1024 * 1024),
        atlas = File(p.join(root.path, 'atlas.png')),
        preview = File(p.join(root.path, 'preview.png'));
    final atlasBytes = await _readSource(atlas, limit: 8 * 1024 * 1024),
        previewBytes = await _readSource(preview, limit: 128 * 1024);
    final meta = await _verifyStored(
      name,
      metaBytes,
      raw,
      atlasBytes,
      previewBytes,
    );
    if (meta.hasLicenseText) {
      utf8.decode(
        await _readSource(File(p.join(root.path, 'license.txt')), limit: 65536),
      );
    }
    _checkOpen();
    return InstalledCharacter(meta, atlas, preview, source);
  }

  static Future<CharacterRenderData> _verifyStored(
    String name,
    Uint8List meta,
    Uint8List source,
    Uint8List atlas,
    Uint8List preview,
  ) => Isolate.run(() {
    final m = CharacterRenderData.fromJson(characterJson(meta));
    if (m.sourceHash != name.substring(0, 64) ||
        sha256.convert(source).toString() != m.sourceHash ||
        sha256.convert(atlas).toString() != m.atlasHash ||
        sha256.convert(preview).toString() != m.previewHash ||
        source.length >
            (m.sourceFormat == 'zip' ? 16 * 1024 * 1024 : 8 * 1024 * 1024)) {
      throw const CharacterPackageFailure(
        'Dữ liệu gói không còn khớp checksum; nguồn được giữ để kiểm tra.',
      );
    }
    final a = CharacterImageProbe.inspect(atlas, expectedFormat: 'png'),
        b = CharacterImageProbe.inspect(preview, expectedFormat: 'png');
    if (a.width != m.width ||
        a.height != m.height ||
        b.width != 128 ||
        b.height != 128) {
      throw const CharacterPackageFailure(
        'Texture của gói không khớp giới hạn.',
      );
    }
    return m;
  });

  File? resolve(String? name) {
    if (!isCharacterAssetName(name) ||
        FileSystemEntity.typeSync(directory.path, followLinks: false) ==
            FileSystemEntityType.link) {
      return null;
    }
    if (_packName(name!)) {
      final root = _packageDirectory(name);
      if (root == null) return null;
      final source = File(p.join(root.path, 'source.bin'));
      return FileSystemEntity.typeSync(source.path, followLinks: false) ==
              FileSystemEntityType.file
          ? source
          : null;
    }
    final path = p.join(directory.path, name);
    if (FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.link) {
      return null;
    }
    return File(path);
  }

  List<String> installed() {
    if (!directory.existsSync() ||
        FileSystemEntity.typeSync(directory.path, followLinks: false) ==
            FileSystemEntityType.link) {
      return [];
    }
    return directory
        .listSync(followLinks: false)
        .where(
          (e) =>
              e is File &&
                  isCharacterAssetName(p.basename(e.path)) &&
                  !_packName(p.basename(e.path)) ||
              e is Directory && _packName(p.basename(e.path)),
        )
        .map((e) => p.basename(e.path))
        .toList()
      ..sort();
  }

  /// Fixed logical names only. Credentials and arbitrary filesystem paths never
  /// enter a backup. Stored packages are verified again before reading them.
  Future<Map<String, Uint8List>> backupFiles(String name) => _trackRead(
    () async {
      _checkOpen();
      if (!installed().contains(name)) {
        throw const ValidationException('Nhân vật không có trong thư viện.');
      }
      final source = resolve(name);
      if (source == null) {
        throw const ValidationException('Nguồn nhân vật bị thiếu.');
      }
      if (!_packName(name)) return {'source.bin': await _readSource(source)};
      final character = await this.character(name);
      if (character == null) {
        throw const ValidationException('Gói nhân vật bị thiếu.');
      }
      final root = _packageDirectory(name)!;
      return {
        'source.bin': await _readSource(source, limit: 16 * 1024 * 1024),
        'atlas.png': await _atlasBytes(character),
        'preview.png': await _readSource(character.preview, limit: 128 * 1024),
        'asset.json': await _readSource(
          File(p.join(root.path, 'asset.json')),
          limit: 65536,
        ),
        if (character.metadata.hasLicenseText)
          'license.txt': await _readSource(
            File(p.join(root.path, 'license.txt')),
            limit: 65536,
          ),
      };
    }(),
  );

  Future<String> restoreBackupFiles(
    String name,
    Map<String, Uint8List> files,
  ) async {
    _checkOpen();
    if (!isCharacterAssetName(name) || !files.containsKey('source.bin')) {
      throw const ValidationException('Mã nhân vật sao lưu không hợp lệ.');
    }
    final source = files['source.bin']!;
    if (sha256.convert(source).toString() != name.substring(0, 64)) {
      throw const ValidationException('Nguồn sao lưu không khớp checksum.');
    }
    if (!_packName(name)) {
      if (files.length != 1) {
        throw const ValidationException('Ảnh tĩnh sao lưu có tệp thừa.');
      }
      return installBytes(source, name);
    }
    if (!files.keys.toSet().containsAll({
          'asset.json',
          'atlas.png',
          'preview.png',
        }) ||
        files.keys.any(
          (k) => !{
            'source.bin',
            'asset.json',
            'atlas.png',
            'preview.png',
            'license.txt',
          }.contains(k),
        )) {
      throw const ValidationException('Gói sao lưu không hợp lệ.');
    }
    final meta = await _verifyStored(
      name,
      files['asset.json']!,
      source,
      files['atlas.png']!,
      files['preview.png']!,
    );
    final plan = await CharacterBlueprint.inspect(
      source,
      meta.sourceFormat,
      'backup',
    );
    if (meta.hasLicenseText != files.containsKey('license.txt') ||
        (meta.hasLicenseText &&
            (plan.licenseBytes == null ||
                sha256.convert(plan.licenseBytes!).toString() !=
                    sha256.convert(files['license.txt']!).toString()))) {
      throw const ValidationException(
        'Giấy phép trong bản sao lưu không khớp nguồn.',
      );
    }
    final preview = StaticAssetPreview._package(
      source,
      PreparedCharacterAnimation(
        meta,
        files['atlas.png']!,
        files['preview.png']!,
        files['license.txt'],
      ),
      'restore.${meta.sourceFormat}',
    );
    return installPrepared(preview, rightsConfirmed: true);
  }

  Future<void> remove(String name) => _serialized(() async {
    if (_packName(name)) {
      final root = _packageDirectory(name);
      if (root == null) {
        throw const ValidationException('Gói nhân vật không hợp lệ.');
      }
      await root.delete(recursive: true);
      _characters.remove(name);
      _renderJobs.clear();
      revision++;
      return;
    }
    final file = resolve(name);
    if (file == null) {
      throw const ValidationException('Tệp nhân vật không hợp lệ.');
    }
    final thumbnail = _thumbnail(name);
    if (await file.exists()) await file.delete();
    if (await thumbnail.exists()) await thumbnail.delete();
    _renderJobs.clear();
    revision++;
  });
}
