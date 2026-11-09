import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/account.dart';

class FirebaseEndpoints {
  const FirebaseEndpoints({
    required this.host,
    this.project = 'demo-daymind',
    this.authPort = 9199,
    this.firestorePort = 8180,
  });
  final String host, project;
  final int authPort, firestorePort;
  Uri auth(String method) => Uri(
    scheme: 'http',
    host: host,
    port: authPort,
    path: '/identitytoolkit.googleapis.com/v1/$method',
    queryParameters: {'key': 'emulator-only'},
  );
  Uri get refresh => Uri(
    scheme: 'http',
    host: host,
    port: authPort,
    path: '/securetoken.googleapis.com/v1/token',
    queryParameters: {'key': 'emulator-only'},
  );
  String get documentPrefix =>
      'projects/$project/databases/(default)/documents';
  Uri firestore(String path, {Map<String, String>? query}) => Uri(
    scheme: 'http',
    host: host,
    port: firestorePort,
    path: '/v1/$documentPrefix$path',
    queryParameters: query,
  );
}

class JsonTransport {
  JsonTransport({
    HttpClient? client,
    this.timeout = const Duration(seconds: 10),
  }) : client = client ?? HttpClient() {
    this.client.connectionTimeout = timeout;
  }
  final HttpClient client;
  final Duration timeout;
  Future<Map<String, dynamic>?> request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    Map<String, String>? form,
    String? token,
    bool missingIsNull = false,
  }) async {
    try {
      final request = await client.openUrl(method, uri).timeout(timeout);
      request.headers.contentType = form == null
          ? ContentType.json
          : ContentType('application', 'x-www-form-urlencoded');
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (form != null) {
        request.write(Uri(queryParameters: form).query);
      } else if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(timeout);
      final bytes = <int>[];
      await for (final chunk in response.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > 16 * 1024 * 1024) {
          throw const AccountFailure(
            'response_limit',
            'Kho dữ liệu vượt giới hạn đồng bộ an toàn trên thiết bị.',
          );
        }
      }
      if (response.statusCode == 404 && missingIsNull) return null;
      final dynamic decoded = bytes.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const AccountFailure(
          'invalid_response',
          'Máy chủ trả về dữ liệu không hợp lệ.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'];
        final raw = error is Map
            ? (error['status'] ??
                      error['message'] ??
                      'HTTP_${response.statusCode}')
                  .toString()
            : 'HTTP_${response.statusCode}';
        final code = raw.split(' : ').first;
        throw AccountFailure(
          code,
          _message(code),
          retryable: response.statusCode == 429 || response.statusCode >= 500,
        );
      }
      return decoded;
    } on AccountFailure {
      rethrow;
    } on TimeoutException {
      throw const AccountFailure(
        'offline',
        'Chưa kết nối được Firebase Emulator. Dữ liệu vẫn được giữ trên thiết bị.',
        retryable: true,
      );
    } on SocketException {
      throw const AccountFailure(
        'offline',
        'Chưa kết nối được Firebase Emulator. Dữ liệu vẫn được giữ trên thiết bị.',
        retryable: true,
      );
    } on HttpException {
      throw const AccountFailure(
        'offline',
        'Kết nối bị gián đoạn. Thay đổi vẫn được giữ để thử lại.',
        retryable: true,
      );
    } on FormatException {
      throw const AccountFailure(
        'invalid_response',
        'Máy chủ trả về dữ liệu không hợp lệ.',
      );
    }
  }

  String _message(String code) => switch (code) {
    'EMAIL_EXISTS' => 'Email thử nghiệm này đã có tài khoản.',
    'EMAIL_NOT_FOUND' ||
    'INVALID_PASSWORD' ||
    'INVALID_LOGIN_CREDENTIALS' => 'Email hoặc mật khẩu chưa đúng.',
    'INVALID_EMAIL' => 'Email không hợp lệ.',
    'WEAK_PASSWORD' => 'Mật khẩu cần ít nhất 6 ký tự.',
    'USER_DISABLED' ||
    'USER_NOT_FOUND' ||
    'INVALID_REFRESH_TOKEN' ||
    'TOKEN_EXPIRED' => 'Phiên đăng nhập cần được xác minh lại.',
    'CREDENTIAL_TOO_OLD_LOGIN_AGAIN' =>
      'Hãy đăng nhập lại trước khi xóa tài khoản.',
    'PERMISSION_DENIED' => 'Không có quyền thay đổi dữ liệu này; hãy kiểm tra tài khoản và trạng thái đồng bộ.',
    'FAILED_PRECONDITION' || 'ALREADY_EXISTS' => 'Dữ liệu trên máy chủ vừa thay đổi. Bản trên thiết bị vẫn được giữ để giải quyết xung đột.',
    _ => 'Chưa hoàn tất yêu cầu tài khoản hoặc đồng bộ. Thay đổi trên thiết bị vẫn được giữ.',
  };
  void close() => client.close(force: true);
}

class FirebaseRestAuth implements AuthGateway {
  FirebaseRestAuth(this.endpoints, this.http, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final FirebaseEndpoints endpoints;
  final JsonTransport http;
  final DateTime Function() clock;
  @override
  Future<AuthSession> signIn(
    String email,
    String password, {
    bool create = false,
  }) async {
    final clean = email.trim();
    if (clean.isEmpty ||
        clean.length > 320 ||
        !clean.contains('@') ||
        password.length < 6 ||
        password.length > 4096) {
      throw const AccountFailure(
        'invalid_credentials',
        'Nhập email và mật khẩu thử nghiệm từ 6 ký tự.',
      );
    }
    final j = (await http.request(
      'POST',
      endpoints.auth(
        create ? 'accounts:signUp' : 'accounts:signInWithPassword',
      ),
      body: {'email': clean, 'password': password, 'returnSecureToken': true},
    ))!;
    return AuthSession.fromJson({
      'uid': j['localId'],
      'email': j['email'] ?? clean,
      'idToken': j['idToken'],
      'refreshToken': j['refreshToken'],
      'expiresAt': clock()
          .toUtc()
          .add(Duration(seconds: int.parse(j['expiresIn'].toString())))
          .toIso8601String(),
    });
  }

  @override
  Future<AuthSession> refresh(AuthSession previous) async {
    final j = (await http.request(
      'POST',
      endpoints.refresh,
      form: {
        'grant_type': 'refresh_token',
        'refresh_token': previous.refreshToken,
      },
    ))!;
    if (j['user_id'] != previous.uid) {
      throw const AccountFailure(
        'owner_mismatch',
        'Phiên đăng nhập không thuộc không gian dữ liệu này.',
      );
    }
    return AuthSession.fromJson({
      'uid': previous.uid,
      'email': previous.email,
      'idToken': j['id_token'],
      'refreshToken': j['refresh_token'],
      'expiresAt': clock()
          .toUtc()
          .add(Duration(seconds: int.parse(j['expires_in'].toString())))
          .toIso8601String(),
    });
  }

  @override
  Future<AuthSession> reauthenticate(
    AuthSession session,
    String password,
  ) async {
    final verified = await signIn(session.email, password);
    if (verified.uid != session.uid) {
      throw const AccountFailure(
        'owner_mismatch',
        'Tài khoản xác minh không khớp.',
      );
    }
    return verified;
  }

  @override
  Future<void> deleteAccount(AuthSession session) async {
    await http.request(
      'POST',
      endpoints.auth('accounts:delete'),
      body: {'idToken': session.idToken},
    );
  }
}
