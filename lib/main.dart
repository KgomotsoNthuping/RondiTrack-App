import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ronditrack/app/provider_retry.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/config/auth_config.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final config = AppConfig.fromEnvironment();
  final authentication = AuthConfig.fromEnvironment();

  runApp(
    ProviderScope(
      retry: appProviderRetry,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        authConfigProvider.overrideWithValue(authentication),
        useApiRepositoriesProvider.overrideWithValue(true),
      ],
      child: RondiTrackApp(config: config),
    ),
  );
}
