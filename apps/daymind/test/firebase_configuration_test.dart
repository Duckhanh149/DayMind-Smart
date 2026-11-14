import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:daymind_smart/features/account_sync/data/firebase_rest.dart';
import 'package:daymind_smart/features/account_sync/domain/account.dart';
import 'package:daymind_smart/platform/secure_session_store.dart';
import 'package:daymind_smart/app/workspace_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final key =
      'AIza${List.filled(35, 'a').join()}'; // synthetic, never sent to Google
  test(
    'default offline and invalid production never fall back to Emulator',
    () {
      for (final c in [
        FirebaseEndpoints.fromBuild(),
        FirebaseEndpoints.fromBuild(
          mode: 'production',
          project: 'demo-daymind',
          apiKey: key,
        ),
        FirebaseEndpoints.fromBuild(mode: 'unexpected'),
        FirebaseEndpoints.fromBuild(
          mode: 'emulator',
          emulatorHost: 'example.com',
        ),
      ]) {
        expect(c.enabled, isFalse);
        expect(() => c.auth('accounts:signUp'), throwsA(isA<AccountFailure>()));
      }
      expect(
        FirebaseEndpoints.fromBuild(integration: true).backend,
        FirebaseBackend.emulator,
      );
    },
  );
  test('production endpoints use only official HTTPS origins and correct project', () {
    final c = FirebaseEndpoints.production(
      project: 'daymind-production',
      apiKey: key,
    );
    expect(c.auth('accounts:signUp').host, 'identitytoolkit.googleapis.com');
    expect(c.refresh.host, 'securetoken.googleapis.com');
    expect(c.firestore('/users/test').host, 'firestore.googleapis.com');
    for (final u in [
      c.auth('accounts:signUp'),
      c.refresh,
      c.firestore('/users/test'),
    ]) {
      expect(u.scheme, 'https');
      expect(u.hasPort, isFalse);
    }
    expect(
      c.firestore('/users/test').path,
      contains(
        'projects/daymind-production/databases/(default)/documents/users/test',
      ),
    );
    expect(c.auth('accounts:signUp').queryParameters['key'], key);
    expect(
      c.storageNamespace,
      isNot(const FirebaseEndpoints(host: '127.0.0.1').storageNamespace),
    );
  });
  test('emulator endpoints reject remote HTTP and non-demo project', () {
    for (final c in [
      const FirebaseEndpoints(host: 'example.com'),
      const FirebaseEndpoints(host: '127.0.0.1', project: 'real-project'),
    ]) {
      expect(() => c.auth('accounts:signUp'), throwsA(isA<AccountFailure>()));
    }
    expect(
      const FirebaseEndpoints(host: '127.0.0.1')
          .auth('accounts:signUp')
          .queryParameters['key'],
      'emulator-only',
    );
  });
  test('trusted Auth response must match project, issuer and UID', () {
    final c = FirebaseEndpoints.production(
      project: 'daymind-production',
      apiKey: key,
    );
    AuthSession session(Map<String, dynamic> claims) => AuthSession(
      uid: 'uid',
      email: 'test@example.invalid',
      idToken:
          'e30.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.synthetic',
      refreshToken: 'synthetic',
      expiresAt: DateTime.utc(2030),
    );
    final claims = {
      'aud': c.project,
      'iss': 'https://securetoken.google.com/${c.project}',
      'sub': 'uid',
    };
    expect(c.validateSessionProject(session(claims)).uid, 'uid');
    for (final altered in [
      {...claims, 'aud': 'other-project'},
      {...claims, 'sub': 'other'},
      {...claims, 'iss': 'http://untrusted.invalid'},
    ]) {
      expect(
        () => c.validateSessionProject(session(altered)),
        throwsA(isA<AccountFailure>()),
      );
    }
  });
  test(
    'production credentials and workspace never reuse Emulator UID storage',
    () async {
      final values = <String, String>{'session': 'legacy-emulator-sentinel'};
      const channel = MethodChannel('daymind/secure');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final a = call.arguments as Map;
            final k = a['key'] as String;
            if (call.method == 'read') return values[k];
            if (call.method == 'write') values[k] = a['value'] as String;
            if (call.method == 'delete') values.remove(k);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final prod = NativeSessionStore(
        namespace: 'production.daymind-production.',
      );
      expect(await prod.read(), isNull);
      await prod.set('session', 'production-sentinel');
      await prod.clear();
      expect(values['session'], 'legacy-emulator-sentinel');
      expect(
        workspacePath(
          '/support',
          'uid',
          namespace: 'production-daymind-production',
        ),
        isNot(workspacePath('/support', 'uid')),
      );
      expect(
        workspacePath(
          '/support',
          null,
          namespace: 'production-daymind-production',
        ),
        '/support',
      );
      expect(
        () => workspacePath('/support', 'uid', namespace: '../../other'),
        throwsArgumentError,
      );
    },
  );
  test('backup owner cannot collide across production projects or Emulator', () {
    final a=FirebaseEndpoints.production(project:'daymind-production',apiKey:key);
    final b=FirebaseEndpoints.production(project:'daymind-other',apiKey:key);
    expect(a.backupOwner('same-uid'),isNot(b.backupOwner('same-uid')));
    expect(a.backupOwner('same-uid'),isNot(const FirebaseEndpoints(host:'127.0.0.1').backupOwner('same-uid')));
    expect(a.backupOwner('same-uid'),isNot(contains('same-uid')));
    expect(a.backupOwner(null),isNull);
  });
  test('transport never forwards a token through redirects', () async {
    var forwarded = false;
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    target.listen((r) async {
      forwarded = true;
      r.response.write('{}');
      await r.response.close();
    });
    origin.listen((r) async {
      r.response.statusCode = 302;
      r.response.headers.set('location', 'http://127.0.0.1:${target.port}/');
      r.response.write('{}');
      await r.response.close();
    });
    final transport = JsonTransport();
    addTearDown(() async {
      transport.close();
      await origin.close(force: true);
      await target.close(force: true);
    });
    await expectLater(
      transport.request(
        'GET',
        Uri.parse('http://127.0.0.1:${origin.port}/'),
        token: 'synthetic-token',
      ),
      throwsA(isA<AccountFailure>()),
    );
    expect(forwarded, isFalse);
  });
}
