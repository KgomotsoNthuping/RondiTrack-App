import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show appFlavor;

/// The build flavours supported by RondiTrack.
enum AppFlavor {
  /// Local development.
  dev,

  /// Testing against staging.
  staging,

  /// Production.
  prod;

  /// The name displayed for this build.
  String get displayName => switch (this) {
    AppFlavor.dev => 'RondiTrack Dev',
    AppFlavor.staging => 'RondiTrack Staging',
    AppFlavor.prod => 'RondiTrack',
  };
}

/// The validated configuration for this run.
final class AppConfig {
  const new _({required this.flavor, required this.apiBaseUrl});

  /// Reads the build flavour and the config supplied at compile time.
  /// Reads and validates the configuration for the current platform.
  factory fromEnvironment() {
    const configuredFlavor = String.fromEnvironment('APP_FLAVOR');

    return AppConfig.parse(
      nativeFlavor: kIsWeb ? configuredFlavor : appFlavor,
      configuredFlavor: configuredFlavor,
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    );
  }

  /// Validates the config against the selected build flavour.
  factory parse({
    required String? nativeFlavor,
    required String configuredFlavor,
    required String apiBaseUrl,
  }) {
    if (configuredFlavor.isEmpty || apiBaseUrl.isEmpty) {
      throw const FormatException(
        'Missing app config. Pass --dart-define-from-file with a config file.',
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

  /// The selected build flavour.
  final AppFlavor flavor;

  /// The API base address for this flavour.
  final Uri apiBaseUrl;
}
