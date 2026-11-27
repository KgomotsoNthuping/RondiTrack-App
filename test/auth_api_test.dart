import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/auth_config.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_api.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/data/auth_paths.dart';
import 'package:ronditrack/core/session/data/dio_auth_api.dart';

final _authConfig = AuthConfig.parse(
  refreshCookieName: 'configured_session',
  refreshCookiePath: '/api/v1/auth',
);

void main() {
  test('native login reads tokens and logs no credentials', () async {
    final adapter = _Adapter()
      ..body = _authBody()
      ..headers = _cookie('first-refresh');

    final logs = <String>[];
    final api = _api(adapter, logs: logs);

    final result = await api.signIn(
      email: 'member@example.invalid',
      password: 'typed-test-password',
    );

    expect(result, isA<Ok<AuthTokens>>());

    final tokens = (result as Ok<AuthTokens>).value;
    final request = adapter.requests.single;

    expect(tokens.identity.userId, 'user-01');
    expect(tokens.refreshToken?.value, 'first-refresh');
    expect(tokens.expiresAtUtc, DateTime.utc(2099));
    expect(request.path, AuthPaths.login);
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(request.headers.containsKey('Cookie'), isFalse);

    expect(request.data, {
      'email': 'member@example.invalid',
      'password': 'typed-test-password',
    });

    final output = logs.join('\n');

    for (final secret in [
      tokens.accessToken,
      'first-refresh',
      'typed-test-password',
      'member@example.invalid',
    ]) {
      expect(output, isNot(contains(secret)));
    }
  });

  test('refresh sends the old cookie and reads its replacement', () async {
    final adapter = _Adapter()
      ..body = _authBody()
      ..headers = _cookie('rotated-refresh');

    final api = _api(adapter);

    final result = await api.refresh(
      refreshToken: const RefreshToken('old-refresh'),
    );

    expect(result, isA<Ok<AuthTokens>>());
    expect(
      (result as Ok<AuthTokens>).value.refreshToken?.value,
      'rotated-refresh',
    );

    final request = adapter.requests.single;

    expect(request.path, AuthPaths.refresh);
    expect(request.data, isNull);
    expect(
      request.headers['Cookie'],
      '${_authConfig.refreshCookieName}=old-refresh',
    );
    expect(request.headers.containsKey('Authorization'), isFalse);
  });

  test('registration returns an account without a session', () async {
    final adapter = _Adapter()
      ..statusCode = 201
      ..body = {
        'id': 'new-user',
        'fullName': 'New Member',
        'email': 'new@example.invalid',
        'phoneNumber': '0710000000',
        'version': 1,
      };

    final result = await _api(adapter).register(
      fullName: 'New Member',
      email: 'new@example.invalid',
      phoneNumber: '0710000000',
      password: 'typed-test-password',
    );

    expect(result, isA<Ok<RegisteredAccount>>());
    expect((result as Ok<RegisteredAccount>).value.userId, 'new-user');

    final request = adapter.requests.single;

    expect(request.path, AuthPaths.register);
    expect(request.headers.containsKey('Cookie'), isFalse);
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(request.data, {
      'fullName': 'New Member',
      'email': 'new@example.invalid',
      'phoneNumber': '0710000000',
      'password': 'typed-test-password',
    });
  });

  test('native login rejects a response without its cookie', () async {
    final adapter = _Adapter()..body = _authBody();

    final result = await _api(
      adapter,
    ).signIn(email: 'member@example.invalid', password: 'typed-test-password');

    expect(
      result,
      isA<Err<AuthTokens>>().having(
        (value) => value.failure,
        'failure',
        isA<ServerFailure>(),
      ),
    );
  });

  test('browser mode leaves cookie handling to the browser', () async {
    final adapter = _Adapter()..body = _authBody();
    final api = _api(adapter, browser: true);

    final login = await api.signIn(
      email: 'member@example.invalid',
      password: 'typed-test-password',
    );

    expect(login, isA<Ok<AuthTokens>>());
    expect((login as Ok<AuthTokens>).value.refreshToken, isNull);

    final refresh = await api.refresh();

    expect(refresh, isA<Ok<AuthTokens>>());
    expect(adapter.requests.last.headers.containsKey('Cookie'), isFalse);

    final rejected = await api.refresh(
      refreshToken: const RefreshToken('manual-refresh'),
    );

    expect(rejected, isA<Err<AuthTokens>>());
    expect(adapter.requests.length, 2);
  });

  for (final token in <RefreshToken?>[
    null,
    const RefreshToken('stored-refresh'),
  ]) {
    test('logout accepts ${token == null ? 'no' : 'a'} cookie', () async {
      final adapter = _Adapter()..statusCode = 204;

      final result = await _api(adapter).logout(refreshToken: token);

      expect(result, isA<Ok<void>>());

      final request = adapter.requests.single;

      expect(request.path, AuthPaths.logout);
      expect(
        request.headers['Cookie'],
        token == null
            ? null
            : '${_authConfig.refreshCookieName}=${token.value}',
      );
      expect(request.sendTimeout, const Duration(seconds: 2));
      expect(request.receiveTimeout, const Duration(seconds: 2));
    });
  }
}

AuthApi _api(_Adapter adapter, {bool browser = false, List<String>? logs}) {
  final config = AppConfig.parse(
    nativeFlavor: 'dev',
    configuredFlavor: 'dev',
    apiBaseUrl: 'http://localhost:5227',
  );

  final dio = createApiDio(
    config,
    writeLog: (line) => logs?.add(line),
    browserCookies: true,
  )..httpClientAdapter = adapter;

  addTearDown(() => dio.close(force: true));

  return DioAuthApi(
    dio: dio,
    config: _authConfig,
    browserManagedCookies: browser,
  );
}

Map<String, Object?> _authBody() {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': 'user-01',
            'email': 'member@example.invalid',
            'role': 'User',
            'jti': 'token-01',
          }),
        ),
      )
      .replaceAll('=', '');

  return {
    'accessToken': 'unchecked-header.$payload.unchecked-signature',
    'expiresAtUtc': DateTime.utc(2099).toIso8601String(),
  };
}

Map<String, List<String>> _cookie(String value) {
  return {
    'set-cookie': [
      '${_authConfig.refreshCookieName}=$value; Path=${_authConfig.refreshCookiePath}; HttpOnly; Secure',
    ],
  };
}

final class _Adapter implements HttpClientAdapter {
  int statusCode = 200;
  Object? body = <String, Object?>{};
  Map<String, List<String>> headers = {};
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);

    return Future.value(
      ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          ...headers,
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}
