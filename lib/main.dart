import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ronditrack/app/provider_retry.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/config/auth_config.dart';
import 'package:ronditrack/core/config/firebase_settings.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/observability/error_reporter.dart';
import 'package:ronditrack/core/observability/sentry_reporting.dart';
import 'package:ronditrack/core/offline/offline_enabled.dart';
import 'package:ronditrack/core/push/data/firebase_installation_messaging.dart';
import 'package:ronditrack/core/push/device_providers.dart';

void main() {
  unawaited(
    runZonedGuarded<Future<void>>(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        usePathUrlStrategy();

        final config = AppConfig.fromEnvironment();
        final authentication = AuthConfig.fromEnvironment();
        final isTest = WidgetsBinding.instance is! WidgetsFlutterBinding;

        final FirebaseSettings firebase;

        try {
          firebase = FirebaseSettings.fromEnvironment();
        } on FormatException catch (error) {
          debugPrint(error.message);
          rethrow;
        }

        await startReporting(flavor: config.flavor, isTest: isTest);

        FlutterError.onError = (details) {
          FlutterError.presentError(details);

          Reporting.capture(
            details.exception,
            details.stack ?? StackTrace.current,
          );
        };

        PlatformDispatcher.instance.onError = (error, stack) {
          Reporting.capture(error, stack);
          return true;
        };

        final messaging = await createInstallationMessaging(
          firebase,
          isTest: isTest,
        );

        runApp(
          ProviderScope(
            retry: appProviderRetry,
            overrides: [
              appConfigProvider.overrideWithValue(config),
              authConfigProvider.overrideWithValue(authentication),
              useApiRepositoriesProvider.overrideWithValue(true),
              offlineEnabledProvider.overrideWithValue(true),
              installationMessagingProvider.overrideWithValue(messaging),
            ],
            child: RondiTrackApp(config: config),
          ),
        );

        if (kDebugMode &&
            config.flavor == AppFlavor.dev &&
            const bool.fromEnvironment('SENTRY_SMOKE_TEST')) {
          Reporting.capture(
            ServerFailure(
              correlationId: '12100000-0000-4000-8000-000000000001',
            ),
            StackTrace.current,
          );
        }
      },
      (Object error, StackTrace stack) {
        if (kDebugMode) {
          debugPrint('Application startup or async operation failed.');
        }

        Reporting.capture(error, stack);
      },
    ),
  );
}
