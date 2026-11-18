import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/app/provider_retry.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/api_result.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/features/auth/application/dev_sign_in_provider.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

const _enabled = bool.fromEnvironment('RUN_LIVE_TESTS');
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _password = String.fromEnvironment('DEV_SEED_PASSWORD');
const _missingCycleId = '00000000-0000-0000-0000-000000000000';

void main() {
  final sessions = <DemoPersona, Result<AccessToken>>{};

  group(
    'live API providers',
    () {
      setUpAll(() async {
        expect(
          _apiBaseUrl,
          isNotEmpty,
          reason: 'Pass API_BASE_URL for the running development API.',
        );
        expect(
          _password,
          isNotEmpty,
          reason: 'Pass DEV_SEED_PASSWORD for the fresh seed.',
        );

        final container = _container(_apiBaseUrl);

        try {
          for (final persona in DemoPersona.values) {
            final accepted = await container
                .read(devSignInProvider.notifier)
                .signIn(persona.email);

            final token = container.read(accessTokenStoreProvider);

            if (accepted && token != null) {
              sessions[persona] = Ok(token);
            } else {
              final error = container.read(devSignInProvider).error;

              sessions[persona] = Err(
                error is Failure ? error : const ServerFailure(),
              );
            }
          }
        } finally {
          container.dispose();
        }
      });

      for (final persona in DemoPersona.values) {
        test('${persona.displayName} Home comes from the API', () async {
          final container = _signedIn(persona, sessions);
          addTearDown(container.dispose);

          final entries = await container.read(
            homeProvider(persona.name).future,
          );

          switch (persona) {
            case DemoPersona.lerato:
              expect(entries, hasLength(2));
              expect(
                entries.singleWhere(
                  (entry) => entry.name == 'Family Savers',
                ).membership.role,
                StokvelRole.treasurer,
              );
              expect(
                entries.singleWhere(
                  (entry) => entry.name == 'Work Savers',
                ).membership.role,
                StokvelRole.member,
              );

            case DemoPersona.nandi:
              expect(entries, hasLength(1));
              expect(entries.single.name, 'Family Savers');
              expect(
                entries.single.membership.role,
                StokvelRole.member,
              );

            case DemoPersona.naledi:
              expect(entries, isEmpty);
          }
        });
      }

      test('a non-member receives NotFound', () async {
        final lerato = _signedIn(DemoPersona.lerato, sessions);
        final nandi = _signedIn(DemoPersona.nandi, sessions);

        addTearDown(lerato.dispose);
        addTearDown(nandi.dispose);

        final entries = await lerato.read(
          homeProvider(DemoPersona.lerato.name).future,
        );

        final work = entries.singleWhere(
          (entry) => entry.name == 'Work Savers',
        );

        final provider = stokvelDetailProvider(
          work.membership.stokvelId,
        );

        await expectLater(
          nandi.read(provider.future),
          throwsA(isA<NotFoundFailure>()),
        );

        expect(
          nandi.read(provider).error,
          isA<NotFoundFailure>(),
        );
      });

      test('a member receives Forbidden and stays signed in', () async {
        final container = _signedIn(DemoPersona.nandi, sessions);
        addTearDown(container.dispose);

        final entries = await container.read(
          homeProvider(DemoPersona.nandi.name).future,
        );

        final familyId = entries.single.membership.stokvelId;

        final probe = FutureProvider<void>((ref) async {
          final result = await apiResult(
            () => ref.read(apiDioProvider).post<Object?>(
              '/api/v1/stokvels/$familyId/'
              'cycles/$_missingCycleId/payout',
            ),
            isRead: false,
          );

          switch (result) {
            case Err(:final failure):
              throw failure;
            case Ok():
              fail('The forbidden probe unexpectedly succeeded.');
          }
        });

        await expectLater(
          container.read(probe.future),
          throwsA(isA<ForbiddenFailure>()),
        );

        expect(
          container.read(demoSessionProvider),
          DemoPersona.nandi,
        );
        expect(
          container.read(accessTokenStoreProvider),
          isNotNull,
        );
      });

      test('an unavailable address becomes OfflineFailure', () async {
        final socket = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );

        final unavailable = 'http://127.0.0.1:${socket.port}';
        await socket.close();

        final container = _signedIn(
          DemoPersona.lerato,
          sessions,
          baseUrl: unavailable,
        );
        addTearDown(container.dispose);

        final provider = homeProvider(DemoPersona.lerato.name);

        await expectLater(
          container.read(provider.future),
          throwsA(isA<OfflineFailure>()),
        );

        expect(
          container.read(provider).error,
          isA<OfflineFailure>(),
        );
      });
    },
    tags: ['live'],
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

ProviderContainer _container(String baseUrl) {
  return ProviderContainer(
    retry: appProviderRetry,
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.parse(
          nativeFlavor: 'dev',
          configuredFlavor: 'dev',
          apiBaseUrl: baseUrl,
        ),
      ),
      useApiRepositoriesProvider.overrideWithValue(true),
      apiLogProvider.overrideWithValue((_) {}),
    ],
  );
}

ProviderContainer _signedIn(
  DemoPersona persona,
  Map<DemoPersona, Result<AccessToken>> sessions, {
  String? baseUrl,
}) {
  final token = switch (sessions[persona]) {
    Ok<AccessToken>(:final value) => value,
    Err<AccessToken>(:final failure) => fail(
      '${persona.displayName} API sign-in failed: ${failure.message}',
    ),
    null => fail('No sign-in result for ${persona.displayName}.'),
  };

  final container = _container(baseUrl ?? _apiBaseUrl);

  container.read(demoSessionProvider.notifier).signIn(persona.email);
  container.read(accessTokenStoreProvider.notifier).save(
    value: token.value,
    expiresAtUtc: token.expiresAtUtc,
    userId: token.userId,
  );

  return container;
}