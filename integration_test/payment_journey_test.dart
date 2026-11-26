import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ronditrack/app/provider_retry.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/config/auth_config.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/core/offline/data/offline_database_provider.dart';
import 'package:ronditrack/core/offline/offline_enabled.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/data/drift_session_persistence.dart';
import 'package:ronditrack/core/session/data/session_interceptor.dart';
import 'package:ronditrack/core/session/refresh_token_store.dart';
import 'package:ronditrack/core/session/session_coordinator.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/core/session/sign_out_marker.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/payments/application/payment_provider.dart';
import 'package:ronditrack/features/payments/application/payment_worker.dart';
import 'package:ronditrack/features/payments/data/payment_outbox.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/data/cached_stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_cache.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_workflow_api.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

import 'support/journey_backend.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'sign in, pay, see the contribution and clear local data on sign-out',
    (tester) async {
      if (!Platform.isAndroid) {
        throw StateError('Run this journey on an Android emulator.');
      }

      final config = AppConfig.fromEnvironment();

      if (config.flavor != AppFlavor.dev ||
          const String.fromEnvironment('SENTRY_DSN').isNotEmpty) {
        throw StateError('Use the dev flavour with an empty SENTRY_DSN.');
      }

      final authentication = AuthConfig.fromEnvironment();
      final directory = await Directory.systemTemp.createTemp(
        'ronditrack-journey-',
      );
      final database = AppDatabase(
        NativeDatabase(File('${directory.path}/journey.sqlite')),
      );
      final backend = JourneyBackend();
      final tokens = MemoryRefreshTokenStore();

      final coordinator = SessionCoordinator(
        api: backend,
        refreshTokenStore: tokens,
        signOutMarker: MemorySignOutMarker(),
        persistence: DriftSessionPersistence(database),
        clock: () => backend.now,
      );

      final retry = Dio(BaseOptions(baseUrl: config.apiBaseUrl.toString()))
        ..httpClientAdapter = backend;

      final client = Dio(BaseOptions(baseUrl: config.apiBaseUrl.toString()))
        ..httpClientAdapter = backend
        ..interceptors.add(
          SessionInterceptor(session: coordinator, retryDio: retry),
        );

      final details = CachedStokvelRepository(
        StokvelWorkflowApi(() => client).detail,
      );

      PaymentWorker? activeWorker;

      try {
        await coordinator.restore();

        await tester.pumpWidget(
          ProviderScope(
            retry: appProviderRetry,
            overrides: [
              appConfigProvider.overrideWithValue(config),
              authConfigProvider.overrideWithValue(authentication),
              useApiRepositoriesProvider.overrideWithValue(true),
              offlineEnabledProvider.overrideWithValue(true),
              offlineDatabaseProvider.overrideWithValue(database),
              sessionCoordinatorProvider.overrideWithValue(coordinator),
              apiDioProvider.overrideWithValue(client),
              homeRepositoryProvider.overrideWith(
                (_) => JourneyHomeRepository(backend),
              ),
              stokvelRepositoryProvider.overrideWith((_) => details),
            ],
            child: RondiTrackApp(config: config),
          ),
        );

        await _show(tester, find.text('Welcome back to RondiTrack.'));

        final email = find.widgetWithText(TextFormField, 'Email');
        final password = find.widgetWithText(TextFormField, 'Password');

        await _show(tester, email, scrollStep: -180);
        await tester.enterText(email, JourneyBackend.email);
        await _show(tester, password, scrollStep: -180);
        await tester.enterText(password, JourneyBackend.password);
        FocusManager.instance.primaryFocus?.unfocus();

        await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));

        await _show(tester, find.text('My Stokvels'));
        expect(backend.signInCalls, 1);

        await _tap(tester, find.text(JourneyBackend.name));
        await _show(tester, find.text('Stokvel details'));
        await _tap(tester, find.text('View cycle'));
        await _show(tester, find.text('Cycle details'));
        await _tap(tester, find.text('Pay contribution'));

        final amount = find.widgetWithText(TextFormField, 'Amount in rands');

        await _show(tester, amount, scrollStep: -180);
        await tester.enterText(amount, '100.00');
        FocusManager.instance.primaryFocus?.unfocus();

        final account = (
          userId: JourneyBackend.userId,
          sessionId: (coordinator.state as AuthSignedIn).sessionId,
        );
        final container = ProviderScope.containerOf(
          tester.element(amount),
          listen: false,
        );

        activeWorker = container.read(paymentWorkerProvider(account));

        await _tap(tester, find.widgetWithText(FilledButton, 'Pay'));

        final paidNotice = '${const Cents(10000).formatRand()} · Paid';

        await _show(tester, find.text(paidNotice), scrollStep: 180);

        await activeWorker.drain();

        expect(
          await PaymentOutbox(database).read(JourneyBackend.userId),
          isEmpty,
        );
        expect(backend.paymentCalls, 1);
        expect(backend.contributionCount, 1);

        await _tap(tester, find.byTooltip('Back'), scrollStep: 0);
        await _show(tester, find.text('Cycle details'));
        await _show(
          tester,
          find.text(JourneyBackend.memberName),
          scrollStep: -180,
        );
        await _show(tester, find.text('Paid'), scrollStep: -180);

        final saved = await StokvelCache(database)
            .read(JourneyBackend.userId, JourneyBackend.stokvelId);

        expect(saved, isNotNull);
        expect(
          saved!.value.contributions.single.id,
          JourneyBackend.contributionId,
        );
        expect(
          saved.value.contributions.single.status,
          ContributionStatus.paid,
        );
        expect(saved.value.currentCycle!.totalCollected.value, 10000);
        expect(backend.unexpectedRequests, isEmpty);

        await binding.convertFlutterSurfaceToImage();
        await tester.pump();

        final image = await binding.takeScreenshot('cycle-paid');
        final screenshot = File(
          '${Directory.systemTemp.path}/ronditrack-cycle-paid.png',
        );

        await screenshot.writeAsBytes(image, flush: true);
        debugPrint('INTEGRATION_SCREENSHOT=${screenshot.path}');

        await _tap(tester, find.text('Profile'), scrollStep: 0);
        await _tap(tester, find.widgetWithText(FilledButton, 'Sign out'));
        await _show(tester, find.text('Welcome back to RondiTrack.'));

        await backend.logoutCompleted.future.timeout(
          const Duration(seconds: 20),
        );

        for (final table in database.allTables) {
          expect(await database.select(table).get(), isEmpty);
        }

        expect(await tokens.read(), isNull);
        expect(coordinator.state, isA<AuthSignedOut>());
        expect(backend.unexpectedRequests, isEmpty);
      } finally {
        if (activeWorker != null) {
          await activeWorker.drain();
        }

        await tester.pumpWidget(const SizedBox.shrink());
        coordinator.dispose();
        client.close(force: true);
        retry.close(force: true);
        await database.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  double scrollStep = -180,
}) async {
  await _show(tester, finder, scrollStep: scrollStep);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _show(
  WidgetTester tester,
  Finder finder, {
  double scrollStep = 0,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));

  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pump();

      if (finder.hitTestable().evaluate().isNotEmpty) {
        return;
      }
    } else if (scrollStep != 0) {
      final scrollables = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            (widget.axisDirection == AxisDirection.down ||
                widget.axisDirection == AxisDirection.up),
      );

      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(scrollables.last, Offset(0, scrollStep));
      }
    }

    await tester.pump(const Duration(milliseconds: 50));
  }

  throw TestFailure('Timed out waiting for visible content: $finder');
}
