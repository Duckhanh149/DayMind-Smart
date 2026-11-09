import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../tasks/domain/task.dart';

class StaticAssetPreview {
  StaticAssetPreview._(Uint8List source, Uint8List preview, this.fileName)
    : _source = source.asUnmodifiableView(),
      bytes = preview.asUnmodifiableView();
  final Uint8List _source;
  final Uint8List bytes;
  final String fileName;
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
  int revision = 0;
  final _renderJobs = <String, Future<File?>>{};
  Future<T> _serialized<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
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

  Future<String> installPrepared(StaticAssetPreview preview) => _serialized(
    () => _installBytes(
      preview._source,
      preview.fileName,
      preview: preview.bytes,
    ),
  );
  Future<String> install(File source, String displayName) async =>
      installBytes(await _readSource(source), displayName);
  Future<Uint8List> _readSource(File source) async {
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const ValidationException(
        'Hãy chọn tệp ảnh thường, không phải liên kết.',
      );
    }
    if (await source.length() > maxBytes) {
      throw const ValidationException('Ảnh tối đa 4 MB.');
    }
    final content = BytesBuilder(copy: false);
    await for (final chunk in source.openRead(0, maxBytes + 1)) {
      content.add(chunk);
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
    await directory.create(recursive: true);
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
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
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
      }
    }
    return (bytes, originals);
  }

  File _thumbnail(String name) {
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
      await staging.writeAsBytes(bytes, flush: true);
      await staging.rename(destination.path);
    } finally {
      if (await staging.exists()) await staging.delete();
    }
  }

  Future<File?> renderFile(String? name) {
    final source = resolve(name);
    if (source == null || !source.existsSync()) return Future.value(null);
    try {
      final thumbnail = _thumbnail(name!);
      if (thumbnail.existsSync()) return Future.value(thumbnail);
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

  File? resolve(String? name) {
    if (name == null || !RegExp(r'^[a-f0-9]{64}\.(png|webp)$').hasMatch(name)) {
      return null;
    }
    final path = p.join(directory.path, name);
    if (FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.link) {
      return null;
    }
    return File(path);
  }

  List<String> installed() {
    if (!directory.existsSync()) {
      return [];
    }
    return directory
        .listSync(followLinks: false)
        .whereType<File>()
        .map((file) => p.basename(file.path))
        .where((name) => RegExp(r'^[a-f0-9]{64}\.(png|webp)$').hasMatch(name))
        .toList()
      ..sort();
  }

  Future<void> remove(String name) => _serialized(() async {
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
