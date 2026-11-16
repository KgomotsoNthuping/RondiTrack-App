import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show appFlavor;

enum AppFlavor {
  dev,
  staging,
  prod;

  String get displayName => switch (this) {
    AppFlavor.dev => 'RondiTrack Dev',
    AppFlavor.staging => 'RondiTrack Staging',
    AppFlavor.prod => 'RondiTrack',
  };
}

final class AppConfig {
  const new _({required this.flavor, required this.apiBaseUrl});

  factory fromEnvironment() {
    const configuredFlavor = String.fromEnvironment('APP_FLAVOR');

    return AppConfig.parse(
      nativeFlavor: kIsWeb ? configuredFlavor : appFlavor,
      configuredFlavor: configuredFlavor,
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    );
  }

  factory parse({
    required String? nativeFlavor,
    required String configuredFlavor,
    required String apiBaseUrl,
  }) {
    if (configuredFlavor.isEmpty || apiBaseUrl.isEmpty) {
      throw const FormatException(
        'Missing app config. Set APP_FLAVOR and API_BASE_URL.',
      );
    }

    final flavor = switch (nativeFlavor) {
      'dev' => AppFlavor.dev,
      'staging' => AppFlavor.staging,
      'prod' => AppFlavor.prod,
      _ => throw StateError('Select dev, staging or prod with --flavor.'),
    };

    if (configuredFlavor != flavor.name) {
      throw StateError(
        'Build flavour "${flavor.name}" does not match '
        'config flavour "$configuredFlavor".',
      );
    }

    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'API_BASE_URL must be an HTTP(S) base URL without credentials, '
        'a query or a fragment.',
      );
    }

    return AppConfig._(flavor: flavor, apiBaseUrl: uri);
  }

  final AppFlavor flavor;
  final Uri apiBaseUrl;
}
