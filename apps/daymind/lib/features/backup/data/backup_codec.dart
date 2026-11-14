import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../domain/backup_snapshot.dart';

/// DMSBKUP1: magic[8], salt[16], nonce[12], ciphertext length BE[4],
/// ciphertext[length], GCM tag[16]. The complete header is authenticated.
/// Fixed algorithms/limits reject attacker-controlled KDF work before deriving.
abstract final class BackupCodec {
  static const maxPlaintext = 96 * 1024 * 1024;
  static const maxFileBytes = maxPlaintext + 56;
  static const iterations = 600000;
  static final _magic = ascii.encode('DMSBKUP1');
  static void validatePassword(String password) {
    if (password.runes.length < 10 || utf8.encode(password).length > 1024) {
      throw const BackupFailure(
        'Mật khẩu sao lưu cần ít nhất 10 ký tự và tối đa 1024 byte. Không thể khôi phục nếu quên mật khẩu.',
      );
    }
  }

  static Future<Uint8List> encrypt(BackupSnapshot snapshot, String password) {
    validatePassword(password);
    return Isolate.run(() async {
      // Utf8Codec already returns a new owned Uint8List. Avoid retaining a
      // second plaintext buffer for large backups; erase this one below.
      final clear = utf8.encode(jsonEncode(snapshot.toJson()));
      if (clear.length > maxPlaintext) invalidBackup();
      final random = Random.secure(), header = Uint8List(40)..setAll(0, _magic);
      for (var i = 8; i < 36; i++) {
        header[i] = random.nextInt(256);
      }
      ByteData.sublistView(header).setUint32(36, clear.length, Endian.big);
      final key = await _key(password, header.sublist(8, 24));
      try {
        final box = await DartAesGcm.with256bits().encrypt(
          clear,
          secretKey: key,
          nonce: header.sublist(24, 36),
          aad: header,
        );
        return Uint8List(clear.length + 56)
          ..setAll(0, header)
          ..setAll(40, box.cipherText)
          ..setAll(40 + clear.length, box.mac.bytes);
      } finally {
        clear.fillRange(0, clear.length, 0);
        key.destroy();
      }
    });
  }

  static Future<BackupSnapshot> decrypt(Uint8List bytes, String password) {
    validatePassword(password);
    if (bytes.length < 56 ||
        bytes.length > maxFileBytes ||
        !List.generate(
          8,
          (i) => bytes[i],
        ).asMap().entries.every((e) => e.value == _magic[e.key])) {
      invalidBackup();
    }
    final size = ByteData.sublistView(bytes).getUint32(36, Endian.big);
    if (size > maxPlaintext || size + 56 != bytes.length) invalidBackup();
    final owned = Uint8List.fromList(bytes);
    return Isolate.run(() async {
      final header = owned.sublist(0, 40),
          key = await _key(password, owned.sublist(8, 24));
      List<int>? clear;
      try {
        clear = await DartAesGcm.with256bits().decrypt(
          SecretBox(
            owned.sublist(40, 40 + size),
            nonce: owned.sublist(24, 36),
            mac: Mac(owned.sublist(40 + size)),
          ),
          secretKey: key,
          aad: header,
        );
        var depth = 0, inString = false, escaped = false;
        for (final byte in clear) {
          if (inString) {
            if (escaped) {
              escaped = false;
            } else if (byte == 92) {
              escaped = true;
            } else if (byte == 34) {
              inString = false;
            }
          } else if (byte == 34) {
            inString = true;
          } else if (byte == 123 || byte == 91) {
            if (++depth > 24) invalidBackup();
          } else if (byte == 125 || byte == 93) {
            if (--depth < 0) invalidBackup();
          }
        }
        if (depth != 0 || inString) invalidBackup();
        // Isolate.run has its own timezone database. Recurrence validation
        // must recognize IANA zones outside UTC before constructing records.
        tzdata.initializeTimeZones();
        return BackupSnapshot.fromJson(jsonDecode(utf8.decode(clear)));
      } on SecretBoxAuthenticationError {
        throw const BackupFailure(
          'Mật khẩu không đúng hoặc tệp đã bị thay đổi. Dữ liệu hiện có vẫn được giữ.',
        );
      } on FormatException {
        invalidBackup();
      } finally {
        clear?.fillRange(0, clear.length, 0);
        key.destroy();
      }
    });
  }

  static Future<SecretKey> _key(String password, List<int> salt) async {
    final input = SecretKeyData(
      utf8.encode(password),
      overwriteWhenDestroyed: true,
    );
    SecretKey? derived;
    try {
      derived = await DartPbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
        pauseFrequency: 0,
      ).deriveKey(secretKey: input, nonce: salt);
      return (await derived.extract()).copy(); // Own an erasable key buffer.
    } finally {
      input.destroy();
      derived?.destroy();
    }
  }
}
