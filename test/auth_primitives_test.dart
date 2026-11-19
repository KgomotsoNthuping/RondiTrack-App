import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/config/auth_config.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/data/auth_claims.dart';
import 'package:ronditrack/core/session/data/auth_cookie.dart';
import 'package:ronditrack/core/session/data/auth_paths.dart';
import 'package:ronditrack/core/session/data/secure_refresh_token_store.dart';
import 'package:ronditrack/core/session/refresh_token_store.dart';

void main() {
  final config = AuthConfig.parse(
    refreshCookieName: 'configured_session',
    refreshCookiePath: '/api/v1/auth',
  );

  test('finds the configured cookie among several headers', () {
    final token = readRefreshCookie([
      'other=value; Path=/',
      '${config.refreshCookieName}_other=ignored; Path=/',
      '${config.refreshCookieName}=private-refresh; '
          'Path=${config.refreshCookiePath}; '
          'Expires=Wed, 25 Nov 2026 12:00:00 GMT; HttpOnly; Secure',
    ], config);

    expect(token.value, 'private-refresh');
  });

  test('rejects a missing cookie', () {
    expect(
      () => readRefreshCookie(['other=value; Path=/'], config),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a mismatched cookie path', () {
    expect(
      () => readRefreshCookie([
        '${config.refreshCookieName}=private-refresh; Path=/',
      ], config),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects duplicate refresh cookies', () {
    final header =
        '${config.refreshCookieName}=private-refresh; '
        'Path=${config.refreshCookiePath}';

    expect(
      () => readRefreshCookie([header, header], config),
      throwsA(isA<FormatException>()),
    );
  });

  test('only sends the refresh cookie to refresh and logout', () {
    const token = RefreshToken('private-refresh');

    for (final path in [AuthPaths.refresh, AuthPaths.logout]) {
      expect(
        refreshCookieHeader(token, config, path: path),
        '${config.refreshCookieName}=private-refresh',
      );
    }

    for (final path in [
      AuthPaths.login,
      AuthPaths.register,
      '/api/v1/me/home',
      '${AuthPaths.refresh}/unexpected',
    ]) {
      expect(
        () => refreshCookieHeader(token, config, path: path),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('rejects unsafe cookie values without exposing them', () {
    const value = 'private-refresh; injected=true';

    expect(
      () => refreshCookieHeader(
        const RefreshToken(value),
        config,
        path: AuthPaths.refresh,
      ),
      throwsA(
        predicate<FormatException>(
          (error) => !error.toString().contains(value),
        ),
      ),
    );
  });

  test('reads claims without verifying a signature', () {
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': 'user-01',
              'email': 'member@example.invalid',
              'role': 'Admin',
              'jti': 'token-01',
            }),
          ),
        )
        .replaceAll('=', '');

    final identity = decodeAuthClaims(
      'unchecked-header.$payload.unchecked-signature',
    );

    expect(identity.userId, 'user-01');
    expect(identity.email, 'member@example.invalid');
    expect(identity.platformRole, 'Admin');
    expect(identity.tokenId, 'token-01');
  });

  test('malformed claims produce a redacted error', () {
    const token = 'private.invalid.token';

    expect(
      () => decodeAuthClaims(token),
      throwsA(
        predicate<FormatException>(
          (error) => !error.toString().contains(token),
        ),
      ),
    );
  });

  test('tests can override secure storage with an in-memory store', () async {
    final container = ProviderContainer.test(
      overrides: [
        refreshTokenStoreProvider.overrideWithValue(MemoryRefreshTokenStore()),
      ],
    );

    final store = container.read(refreshTokenStoreProvider);

    expect(await store.read(), isNull);

    await store.write(const RefreshToken('first-refresh'));
    expect((await store.read())?.value, 'first-refresh');

    await store.write(const RefreshToken('rotated-refresh'));
    expect((await store.read())?.value, 'rotated-refresh');

    await store.clear();
    expect(await store.read(), isNull);
  });

  test('refresh token string output is redacted', () {
    const token = RefreshToken('private-refresh');

    expect(token.toString(), isNot(contains(token.value)));
  });
}
