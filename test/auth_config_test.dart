import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/config/auth_config.dart';

void main() {
  test('rejects a missing refresh cookie name', () {
    expect(
      () => AuthConfig.parse(
        refreshCookieName: '',
        refreshCookiePath: '/api/v1/auth',
      ),
      throwsFormatException,
    );
  });

  test('rejects a missing refresh cookie path', () {
    expect(
      () => AuthConfig.parse(
        refreshCookieName: 'configured_session',
        refreshCookiePath: '',
      ),
      throwsFormatException,
    );
  });

  test('preserves the configured name and path', () {
    final config = AuthConfig.parse(
      refreshCookieName: 'configured_session',
      refreshCookiePath: '/api/v1/auth',
    );

    expect(config.refreshCookieName, 'configured_session');
    expect(config.refreshCookiePath, '/api/v1/auth');
  });

  const invalidNames = [
    'cookie name',
    'cookie;name',
    'cookie=value',
    'cookie\r\nname',
    'cookie\n',
  ];

  for (final (index, name) in invalidNames.indexed) {
    test('rejects unsafe cookie name $index', () {
      expect(
        () => AuthConfig.parse(
          refreshCookieName: name,
          refreshCookiePath: '/api/v1/auth',
        ),
        throwsFormatException,
      );
    });
  }

  const invalidPaths = [
    'api/v1/auth',
    'https://fixture.invalid/auth',
    '//fixture.invalid/auth',
    '/api/v1/auth?value=1',
    '/api/v1/auth#fragment',
    '/api/../auth',
    '/api/v1/auth;value',
    '/api/v1/auth\n',
    r'/api\auth',
  ];

  for (final (index, path) in invalidPaths.indexed) {
    test('rejects unsafe cookie path $index', () {
      expect(
        () => AuthConfig.parse(
          refreshCookieName: 'configured_session',
          refreshCookiePath: path,
        ),
        throwsFormatException,
      );
    });
  }

  for (final root in ['config', 'lib/core/config']) {
    for (final flavor in ['dev', 'staging', 'prod']) {
      final path = '$root/$flavor.json';

      test('$path provides valid authentication configuration', () async {
        final settings =
            jsonDecode(await File(path).readAsString()) as Map<String, Object?>;

        final config = AuthConfig.parse(
          refreshCookieName: settings['REFRESH_COOKIE_NAME']! as String,
          refreshCookiePath: settings['REFRESH_COOKIE_PATH']! as String,
        );

        expect(config.refreshCookieName, settings['REFRESH_COOKIE_NAME']);
        expect(config.refreshCookiePath, settings['REFRESH_COOKIE_PATH']);
      });
    }
  }
}
