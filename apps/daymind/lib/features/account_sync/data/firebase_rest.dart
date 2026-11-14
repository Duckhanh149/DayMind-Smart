import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../domain/account.dart';

enum FirebaseBackend { disabled, emulator, production }

class FirebaseEndpoints {
  const FirebaseEndpoints({
    required this.host,
    this.project = 'demo-daymind',
    this.authPort = 9199,
    this.firestorePort = 8180,
  }) : backend = FirebaseBackend.emulator,
       apiKey = '',
       issue = null;
  const FirebaseEndpoints._({
    required this.backend,
    this.project = '',
    this.apiKey = '',
    this.issue,
  }) : host = '',
       authPort = 0,
       firestorePort = 0;
  factory FirebaseEndpoints.production({
    required String project,
    required String apiKey,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(project) ||
        project.startsWith('demo-') ||
        !RegExp(r'^AIza[A-Za-z0-9_-]{35}$').hasMatch(apiKey)) {
      throw const FormatException('Cấu hình Firebase production chưa hợp lệ.');
    }
    return FirebaseEndpoints._(
      backend: FirebaseBackend.production,
      project: project,
      apiKey: apiKey,
    );
  }
  factory FirebaseEndpoints.fromBuild({
    String mode = const String.fromEnvironment('DAYMIND_FIREBASE_MODE'),
    String project = const String.fromEnvironment('DAYMIND_FIREBASE_PROJECT'),
    String apiKey = const String.fromEnvironment('DAYMIND_FIREBASE_API_KEY'),
    String emulatorHost = const String.fromEnvironment('DAYMIND_EMULATOR_HOST'),
    bool integration = const bool.fromEnvironment('RUN_ACCOUNT_EMULATOR'),
    bool android = false,
  }) {
    if (mode == 'production') {
      try {
        return FirebaseEndpoints.production(project: project, apiKey: apiKey);
      } on FormatException {
        return const FirebaseEndpoints._(
          backend: FirebaseBackend.disabled,
          issue: 'production_config_missing',
        );
      }
    }
    if (mode == 'emulator' || (mode.isEmpty && integration)) {
      final h = emulatorHost.isEmpty
          ? (android ? '10.0.2.2' : '127.0.0.1')
          : emulatorHost;
      if (!{'127.0.0.1', 'localhost', '::1', '10.0.2.2'}.contains(h)) {
        return const FirebaseEndpoints._(
          backend: FirebaseBackend.disabled,
          issue: 'emulator_host_invalid',
        );
      }
      return FirebaseEndpoints(host: h);
    }
    return FirebaseEndpoints._(
      backend: FirebaseBackend.disabled,
      issue: mode.isEmpty || mode == 'disabled' ? null : 'mode_invalid',
    );
  }
  final FirebaseBackend backend;
  final String host, project, apiKey;
  final String? issue;
  final int authPort, firestorePort;
  bool get enabled => backend != FirebaseBackend.disabled;
  bool get isProduction => backend == FirebaseBackend.production;
  String get storageNamespace => switch (backend) {
    FirebaseBackend.emulator => '',
    FirebaseBackend.production => 'production.$project.',
    FirebaseBackend.disabled => 'offline.',
  };
  String? backupOwner(String? uid) => uid == null
      ? null
      : isProduction
      ? 'production:${sha256.convert(utf8.encode('$project|$uid'))}'
      : uid;
  String get accountNamespace => isProduction ? 'production-$project' : '';
  String get label => switch (backend) {
    FirebaseBackend.production => 'Firebase production',
    FirebaseBackend.emulator => 'Firebase Emulator · thử nghiệm',
    FirebaseBackend.disabled => 'Lưu cục bộ · đồng bộ chưa được cấu hình',
  };
  String get description => switch (backend) {
    FirebaseBackend.production => 'Đồng bộ qua kết nối HTTPS khi bạn đăng nhập. Dữ liệu và phiên đăng nhập tách khỏi môi trường thử nghiệm; ảnh nhân vật không được tải lên.',
    FirebaseBackend.emulator => 'Chỉ dùng email và mật khẩu thử nghiệm. Máy chủ thử phải đang chạy; không dùng thông tin đăng nhập thật. Dữ liệu cục bộ vẫn dùng được khi offline.',
    FirebaseBackend.disabled =>
      issue == null
          ? 'Công việc và sao lưu trên thiết bị vẫn dùng được. Bản app này chưa bật đăng nhập/đồng bộ cloud.'
          : 'Cấu hình đồng bộ chưa hợp lệ nên kết nối cloud đã tắt. Dữ liệu cục bộ vẫn được giữ; không tự chuyển sang máy chủ thử nghiệm.',
  };
  void _requireEndpoint() {
    if (!enabled) {
      throw const AccountFailure(
        'not_configured',
        'Đồng bộ chưa được cấu hình. Dữ liệu cục bộ vẫn được giữ.',
      );
    }
    if (!isProduction &&
        (!project.startsWith('demo-') ||
            !RegExp(r'^demo-[a-z0-9-]+$').hasMatch(project) ||
            !{'127.0.0.1', 'localhost', '::1', '10.0.2.2'}.contains(host) ||
            authPort < 1 ||
            authPort > 65535 ||
            firestorePort < 1 ||
            firestorePort > 65535)) {
      throw const AccountFailure(
        'invalid_emulator',
        'Máy chủ thử nghiệm phải dùng project demo và địa chỉ loopback.',
      );
    }
  }

  Uri auth(String method) {
    _requireEndpoint();
    return isProduction
        ? Uri.https('identitytoolkit.googleapis.com', '/v1/$method', {
            'key': apiKey,
          })
        : Uri(
            scheme: 'http',
            host: host,
            port: authPort,
            path: '/identitytoolkit.googleapis.com/v1/$method',
            queryParameters: {'key': 'emulator-only'},
          );
  }

  Uri get refresh {
    _requireEndpoint();
    return isProduction
        ? Uri.https('securetoken.googleapis.com', '/v1/token', {'key': apiKey})
        : Uri(
            scheme: 'http',
            host: host,
            port: authPort,
            path: '/securetoken.googleapis.com/v1/token',
            queryParameters: {'key': 'emulator-only'},
          );
  }

  String get documentPrefix {
    _requireEndpoint();
    return 'projects/$project/databases/(default)/documents';
  }

  Uri firestore(String path, {Map<String, String>? query}) {
    _requireEndpoint();
    return isProduction
        ? Uri.https(
            'firestore.googleapis.com',
            '/v1/$documentPrefix$path',
            query,
          )
        : Uri(
            scheme: 'http',
            host: host,
            port: firestorePort,
            path: '/v1/$documentPrefix$path',
            queryParameters: query,
          );
  }

  /// Check trusted Auth REST response belongs to this configured project.
  /// This is not JWT signature verification; Firebase validates signatures server-side.
  AuthSession validateSessionProject(AuthSession session) {
    if (!isProduction) return session;
    try {
      final parts = session.idToken.split('.');
      if (parts.length != 3) throw const FormatException();
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (claims is! Map ||
          claims['aud'] != project ||
          claims['iss'] != 'https://securetoken.google.com/$project' ||
          claims['sub'] != session.uid) {
        throw const FormatException();
      }
    } catch (_) {
      throw const AccountFailure(
        'project_mismatch',
        'Phiên đăng nhập không khớp dự án đồng bộ. Hãy kiểm tra cấu hình ứng dụng.',
      );
    }
    return session;
  }
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
      request.followRedirects = false;
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
        final candidate = raw.split(' : ').first;
        final code = RegExp(r'^[A-Z0-9_]{1,64}$').hasMatch(candidate)
            ? candidate
            : 'backend_error';
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
        'Chưa kết nối được máy chủ đồng bộ. Dữ liệu vẫn được giữ trên thiết bị.',
        retryable: true,
      );
    } on SocketException {
      throw const AccountFailure(
        'offline',
        'Chưa kết nối được máy chủ đồng bộ. Dữ liệu vẫn được giữ trên thiết bị.',
        retryable: true,
      );
    } on HandshakeException {
      throw const AccountFailure(
        'tls',
        'Không xác minh được kết nối an toàn tới máy chủ. Không gửi tiếp dữ liệu.',
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
    'EMAIL_EXISTS' => 'Email này đã có tài khoản.',
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
    return endpoints.validateSessionProject(
      AuthSession.fromJson({
        'uid': j['localId'],
        'email': j['email'] ?? clean,
        'idToken': j['idToken'],
        'refreshToken': j['refreshToken'],
        'expiresAt': clock()
            .toUtc()
            .add(Duration(seconds: int.parse(j['expiresIn'].toString())))
            .toIso8601String(),
      }),
    );
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
    return endpoints.validateSessionProject(
      AuthSession.fromJson({
        'uid': previous.uid,
        'email': previous.email,
        'idToken': j['id_token'],
        'refreshToken': j['refresh_token'],
        'expiresAt': clock()
            .toUtc()
            .add(Duration(seconds: int.parse(j['expires_in'].toString())))
            .toIso8601String(),
      }),
    );
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
