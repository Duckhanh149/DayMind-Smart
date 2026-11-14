import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../features/account_sync/domain/account.dart';

/// Native OS encryption: Android Keystore AES-GCM / Windows user-bound DPAPI.
class NativeSessionStore implements SecureSessionStore {
  NativeSessionStore({this.namespace = ''});
  final String namespace;
  static const channel = MethodChannel('daymind/secure');
  Future<String?> get(String key) =>
      channel.invokeMethod<String>('read', {'key': '$namespace$key'});
  Future<void> set(String key, String value) => channel.invokeMethod<void>(
    'write',
    {'key': '$namespace$key', 'value': value},
  );
  Future<void> remove(String key) =>
      channel.invokeMethod<void>('delete', {'key': '$namespace$key'});
  @override
  Future<AuthSession?> read() async {
    final raw = await get('session');
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      throw const AccountFailure(
        'invalid_session',
        'Chưa đọc được phiên đăng nhập đã lưu. Hãy đăng nhập lại.',
      );
    }
  }

  @override
  Future<void> write(AuthSession session) =>
      set('session', jsonEncode(session.toJson()));
  @override
  Future<void> clear() => remove('session');
  Future<String> installationId() async {
    final old = await get('installation');
    if (old != null && Uuid.isValidUUID(fromString: old)) return old;
    final value = const Uuid().v4();
    await set('installation', value);
    return value;
  }
}
