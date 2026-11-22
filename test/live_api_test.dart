@Tags(['live'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/app/provider_retry.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/config/auth_config.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/api_dio_factory.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/data/auth_api_provider.dart';
import 'package:ronditrack/core/session/data/secure_refresh_token_store.dart';
import 'package:ronditrack/core/session/refresh_token_store.dart';
import 'package:ronditrack/core/session/session_coordinator.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';

void main() {
  final enabled = Platform.environment['RUN_LIVE_TESTS'] == 'true';

  late ProviderContainer container;
  late SessionCoordinator session;

  ProviderContainer? cleanupContainer;
  SessionCoordinator? cleanupSession;

  final store = MemoryRefreshTokenStore();

  group('live authenticated API', () {
    setUpAll(() async {
      final email = Platform.environment['RONDITRACK_TEST_EMAIL'];
      final password = Platform.environment['RONDITRACK_TEST_PASSWORD'];
      final baseUrl = Platform.environment['RONDITRACK_TEST_API_BASE_URL'];

      if (email == null ||
          password == null ||
          baseUrl == null ||
          email.isEmpty ||
          password.isEmpty ||
          baseUrl.isEmpty) {
        fail('Set the runtime test email, password and API base URL.');
      }

      container = ProviderContainer(
        retry: appProviderRetry,
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              nativeFlavor: 'dev',
              configuredFlavor: 'dev',
              apiBaseUrl: baseUrl,
            ),
          ),
          authConfigProvider.overrideWithValue(AuthConfig.fromEnvironment()),
          useApiRepositoriesProvider.overrideWithValue(true),
          refreshTokenStoreProvider.overrideWithValue(store),
          apiLogProvider.overrideWithValue((_) {}),
        ],
      );

      cleanupContainer = container;

      session = container.read(sessionCoordinatorProvider);
      cleanupSession = session;

      await session.restore();

      final result = await session.signIn(email: email, password: password);

      expect(result is Ok<void>, isTrue, reason: 'Live sign-in failed.');
    });

    tearDownAll(() async {
      try {
        await cleanupSession?.signOut();
      } finally {
        cleanupContainer?.dispose();
      }
    });

    test('Home loads for the authenticated API user', () async {
      final state = session.state;

      expect(state is AuthSignedIn, isTrue);

      final userId = (state as AuthSignedIn).identity.userId;

      await container.read(homeProvider(userId).future);

      expect(session.state is AuthSignedIn, isTrue);
    });

    test('a missing stokvel produces NotFound', () async {
      await expectLater(
        container.read(
          stokvelDetailProvider('00000000-0000-0000-0000-000000000000').future,
        ),
        throwsA(isA<NotFoundFailure>()),
      );

      expect(session.state is AuthSignedIn, isTrue);
    });

    test('a new coordinator restores the stored session', () async {
      final restarted = SessionCoordinator(
        api: container.read(authApiProvider),
        refreshTokenStore: store,
      );

      try {
        final restored = await restarted.restore();

        expect(restored is Ok<void>, isTrue);
        expect(restarted.state is AuthSignedIn, isTrue);
        expect(await store.read() != null, isTrue);
      } finally {
        restarted.dispose();
      }
    });
  }, skip: !enabled);
}
