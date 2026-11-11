import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/config/app_config.dart';

void main() {
  test('rejects startup without config', () {
    expect(
      () => AppConfig.parse(
        nativeFlavor: 'prod',
        configuredFlavor: '',
        apiBaseUrl: '',
      ),
      throwsFormatException,
    );
  });

  test('rejects dev config for a prod build', () {
    expect(
      () => AppConfig.parse(
        nativeFlavor: 'prod',
        configuredFlavor: 'dev',
        apiBaseUrl: 'http://10.0.2.2:5227',
      ),
      throwsStateError,
    );
  });

  test('requires a build flavour even when config is present', () {
    expect(
      () => AppConfig.parse(
        nativeFlavor: null,
        configuredFlavor: 'dev',
        apiBaseUrl: 'http://10.0.2.2:5227',
      ),
      throwsStateError,
    );
  });

  for (final flavor in AppFlavor.values) {
    test('accepts config/${flavor.name}.json for its build', () async {
      final file = File('config/${flavor.name}.json');
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      final url = json['API_BASE_URL']! as String;

      final config = AppConfig.parse(
        nativeFlavor: flavor.name,
        configuredFlavor: json['APP_FLAVOR']! as String,
        apiBaseUrl: url,
      );

      expect(config.flavor, flavor);
      expect(config.apiBaseUrl, Uri.parse(url));
    });
  }
}
