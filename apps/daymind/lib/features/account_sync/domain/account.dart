class AccountFailure implements Exception {
  const AccountFailure(this.code, this.message, {this.retryable = false});
  final String code, message;
  final bool retryable;
  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });
  final String uid, email, idToken, refreshToken;
  final DateTime expiresAt;
  bool refreshDue(DateTime now) =>
      !expiresAt.isAfter(now.add(const Duration(minutes: 1)));
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'idToken': idToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
  factory AuthSession.fromJson(Map<String, dynamic> j) {
    final value = AuthSession(
      uid: j['uid'] as String,
      email: j['email'] as String,
      idToken: j['idToken'] as String,
      refreshToken: j['refreshToken'] as String,
      expiresAt: DateTime.parse(j['expiresAt'] as String).toUtc(),
    );
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(value.uid) ||
        value.email.length > 320 ||
        value.idToken.isEmpty ||
        value.refreshToken.isEmpty ||
        value.idToken.length > 16384 ||
        value.refreshToken.length > 16384) {
      throw const AccountFailure(
        'invalid_session',
        'Phiên đăng nhập không hợp lệ.',
      );
    }
    return value;
  }
}

abstract interface class AuthGateway {
  Future<AuthSession> signIn(
    String email,
    String password, {
    bool create = false,
  });
  Future<AuthSession> refresh(AuthSession previous);
  Future<AuthSession> reauthenticate(AuthSession session, String password);
  Future<void> deleteAccount(AuthSession session);
}

abstract interface class SecureSessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}
