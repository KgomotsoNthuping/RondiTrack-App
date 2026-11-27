import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/offline/offline_enabled.dart';
import 'package:ronditrack/core/push/notification_providers.dart';
import 'package:ronditrack/core/push/push_runtime.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/refresh_token_store.dart';
import 'package:ronditrack/core/session/session_coordinator.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/presentation/home_screen.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_repository.dart';

import '../support/assignment_12_1_fixtures.dart';
import '../support/notification_fakes.dart';

void main() {
  for (final mode in ['member', 'signed-out', 'other-member']) {
    testWidgets('cold notification opens safely: $mode', (tester) async {
      final h = await _Harness.create(mode);

      try {
        await h.pump(tester);

        const target = '/stokvels/$testStokvelId/cycles/$testCycleId';

        if (mode == 'signed-out') {
          expect(find.text('Welcome back to RondiTrack.'), findsOneWidget);
          expect(h.uri.path, '/sign-in');
          expect(h.uri.queryParameters['from'], target);
          expect(h.repository.readers, isEmpty);

          await tester.enterText(
            find.byKey(const ValueKey('sign-in-email')),
            testIdentity.email,
          );
          await tester.enterText(
            find.byKey(const ValueKey('sign-in-password')),
            'test-only-password',
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('sign-in-submit')),
          );
          await tester.tap(find.byKey(const ValueKey('sign-in-submit')));

          await _settleWithoutHome(tester);
        }

        expect(h.uri.path, target);
        expect(find.text('Cycle details'), findsOneWidget);

        if (mode == 'other-member') {
          expect(find.text('Not found'), findsOneWidget);
          expect(find.text('Cycle 1'), findsNothing);
          expect(h.repository.readers, everyElement(_otherUser));
        } else {
          expect(find.text('Cycle 1'), findsOneWidget);
          expect(h.repository.readers, everyElement(testUserId));
        }

        expect(h.repository.readers, isNotEmpty);
        expect(h.local.requests, 0);
        expect(find.text('Get payment updates?'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    });
  }

  testWidgets('push off ignores payment events without asking', (tester) async {
    final h = await _Harness.create('member', pushOff: true);

    try {
      await h.pump(tester, allowHome: true);

      h.container.read(paymentRecordedProvider.notifier).record();

      await tester.pumpAndSettle();

      expect(find.text('Get payment updates?'), findsNothing);
      expect(h.local.requests, 0);
      expect(h.preferences.reads, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await h.close(tester);
    }
  });

  testWidgets('foreground push refetches the exact visible cycle when denied', (
    tester,
  ) async {
    final h = await _Harness.create('member');

    try {
      await h.pump(tester);

      final reads = h.repository.readers.length;

      h.repository.stock = testStokvel.copyWith(
        currentCycle: testStokvel.currentCycle!.copyWith(
          targetAmount: const Cents(70000),
        ),
      );

      h.messages.received.add(pushData);

      await _settleWithoutHome(tester);

      expect(h.repository.readers.length, greaterThan(reads));
      expect(
        find.text('Target ${const Cents(70000).formatRand()}'),
        findsOneWidget,
      );
      expect(h.local.shown, isEmpty);
      expect(h.uri.path, '/stokvels/$testStokvelId/cycles/$testCycleId');
      expect(tester.takeException(), isNull);
    } finally {
      await h.close(tester);
    }
  });

  testWidgets('payment event explains once; Not now never requests Android', (
    tester,
  ) async {
    final h = await _Harness.create('member');

    try {
      await h.pump(tester);

      expect(find.text('Get payment updates?'), findsNothing);

      h.container.read(paymentRecordedProvider.notifier).record();

      await tester.pumpAndSettle();

      expect(find.text('Get payment updates?'), findsOneWidget);
      expect(h.local.requests, 0);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      h.container.read(paymentRecordedProvider.notifier).record();

      await tester.pumpAndSettle();

      expect(find.text('Get payment updates?'), findsNothing);
      expect(h.local.requests, 0);
      expect(h.preferences.value, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      await h.close(tester);
    }
  });
}

const _otherUser = '44444444-4444-4444-8444-444444444444';

Future<void> _settleWithoutHome(WidgetTester tester) async {
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(HomeScreen), findsNothing);
  }
}

final class _CycleRepository implements StokvelCycleRepository {
  Stokvel stock = testStokvel;

  final readers = <String>[];

  @override
  Future<Stokvel?> fetchDetail(String userId, String stokvelId) async => null;

  @override
  Future<Stokvel?> fetchCycleDetail(
    String userId,
    String stokvelId,
    String cycleId,
  ) async {
    readers.add(userId);

    if (userId != testUserId ||
        stokvelId != testStokvelId ||
        cycleId != testCycleId) {
      return null;
    }

    return stock;
  }
}

final class _Harness {
  new(
    this.container,
    this.coordinator,
    this.messages,
    this.local,
    this.runtime,
    this.repository,
    this.preferences,
    this.config,
  );

  final ProviderContainer container;
  final SessionCoordinator coordinator;
  final TestPushMessages messages;
  final TestLocalNotifications local;
  final PushRuntime runtime;
  final _CycleRepository repository;
  final TestNotificationPreferences preferences;
  final AppConfig config;

  Uri get uri => container
      .read(appRouterProvider(config.flavor))
      .routeInformationProvider
      .value
      .uri;

  static Future<_Harness> create(String mode, {bool pushOff = false}) async {
    final auth = MockAuthApi();

    when(() => auth.browserManagedCookies).thenReturn(false);

    when(
      () => auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => Ok(
        AuthTokens(
          accessToken: 'test-token',
          expiresAtUtc: testNow.add(const Duration(minutes: 10)),
          identity: mode == 'other-member'
              ? const AuthIdentity(
                  userId: _otherUser,
                  email: 'other@example.invalid',
                )
              : testIdentity,
          refreshToken: const RefreshToken('test-refresh-token'),
        ),
      ),
    );

    final coordinator = SessionCoordinator(
      api: auth,
      refreshTokenStore: MemoryRefreshTokenStore(),
      clock: () => testNow,
    );

    await coordinator.restore();

    if (mode != 'signed-out') {
      await coordinator.signIn(
        email: testIdentity.email,
        password: 'test-only-password',
      );
    }

    final messages = TestPushMessages(first: pushOff ? null : pushData);

    final local = TestLocalNotifications();

    final runtime = pushOff
        ? PushRuntime.disabled()
        : PushRuntime(messages: messages, notifications: local);

    await runtime.start();

    final repository = _CycleRepository();
    final preferences = TestNotificationPreferences();
    final home = MockHomeRepository();

    when(() => home.fetchHome(any()))
        .thenAnswer((_) async => mode == 'other-member' ? [] : [testHomeEntry]);

    final config = AppConfig.parse(
      nativeFlavor: 'dev',
      configuredFlavor: 'dev',
      apiBaseUrl: 'https://api.example.invalid',
    );

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        useApiRepositoriesProvider.overrideWithValue(true),
        offlineEnabledProvider.overrideWithValue(false),
        sessionCoordinatorProvider.overrideWithValue(coordinator),
        homeRepositoryProvider.overrideWithValue(home),
        stokvelRepositoryProvider.overrideWithValue(repository),
        pushRuntimeProvider.overrideWithValue(runtime),
        notificationPreferencesProvider.overrideWithValue(preferences),
      ],
    );

    return _Harness(
      container,
      coordinator,
      messages,
      local,
      runtime,
      repository,
      preferences,
      config,
    );
  }

  Future<void> pump(WidgetTester tester, {bool allowHome = false}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RondiTrackApp(config: config),
      ),
    );

    if (allowHome) {
      await tester.pumpAndSettle();
    } else {
      expect(find.byType(HomeScreen), findsNothing);

      await _settleWithoutHome(tester);
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());

    container.dispose();
    coordinator.dispose();

    await runtime.dispose();
    await messages.close();
    await local.close();
  }
}
