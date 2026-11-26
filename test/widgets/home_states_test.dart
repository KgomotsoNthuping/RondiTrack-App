import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/offline/cache_controller.dart';
import 'package:ronditrack/core/offline/cached_value.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/core/offline/data/offline_database_provider.dart';
import 'package:ronditrack/core/offline/offline_enabled.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/domain/home_repository.dart';
import 'package:ronditrack/features/offline/application/offline_account_provider.dart';
import 'package:ronditrack/features/payments/application/payment_provider.dart';
import 'package:ronditrack/features/payments/application/payment_worker.dart';
import 'package:ronditrack/features/payments/data/payment_outbox.dart';
import 'package:ronditrack/features/payments/domain/pending_payment.dart';

import '../support/assignment_12_1_fixtures.dart';

enum _HomeState { loading, data, empty, failure, cached }

void main() {
  for (final brightness in Brightness.values) {
    for (final state in _HomeState.values) {
      testWidgets('Home ${state.name} is accessible in ${brightness.name}', (
        tester,
      ) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(390, 1400);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dispatcher = tester.binding.platformDispatcher
          ..platformBrightnessTestValue = brightness;
        addTearDown(dispatcher.clearPlatformBrightnessTestValue);

        final semantics = tester.ensureSemantics();
        final pending = Completer<List<HomeEntry>>();
        final repository = _HomeRepository((call) async {
          return switch (state) {
            _HomeState.loading => await pending.future,
            _HomeState.data => [testHomeEntry],
            _HomeState.empty => [],
            _HomeState.failure when call == 1 => throw const ServerFailure(
              correlationId: 'home-read-503',
            ),
            _HomeState.failure => [testHomeEntry],
            _HomeState.cached => throw const OfflineFailure(isRead: true),
          };
        });
        final h = await _HomeHarness.pump(
          tester,
          repository,
          cached: state == _HomeState.cached,
        );

        try {
          await tester.pump(const Duration(milliseconds: 300));

          if (state != _HomeState.loading) {
            await tester.pumpAndSettle();
          }

          final context = tester.element(find.text('RondiTrack'));

          expect(
            GoRouter.of(context).routeInformationProvider.value.uri.path,
            '/',
          );
          expect(Theme.of(context).brightness, brightness);
          expect(find.text('RondiTrack'), findsOneWidget);
          expect(repository.calls, 1);

          switch (state) {
            case _HomeState.loading:
              expect(find.bySemanticsLabel('Loading data'), findsOneWidget);
              expect(find.text('Test Savings'), findsNothing);

            case _HomeState.data:
              expect(find.text('My Stokvels'), findsOneWidget);
              expect(find.text('Test Savings'), findsOneWidget);
              expect(find.text('Member'), findsOneWidget);
              expect(find.text('Paid this cycle'), findsOneWidget);
              expect(find.text('Still owed'), findsOneWidget);
              expect(
                find.bySemanticsLabel(RegExp('Open Test Savings')),
                findsOneWidget,
              );

            case _HomeState.empty:
              expect(find.text('You have no stokvels yet.'), findsOneWidget);
              expect(
                find.text('Ask a stokvel administrator to send you an invite.'),
                findsOneWidget,
              );
              expect(find.text('Create stokvel'), findsOneWidget);

            case _HomeState.failure:
              expect(
                find.text('Sorry, something went wrong on our side.'),
                findsOneWidget,
              );
              expect(find.text('Reference: home-read-503'), findsOneWidget);
              expect(find.text('Try again'), findsOneWidget);

            case _HomeState.cached:
              expect(find.text('Test Savings'), findsOneWidget);
              expect(
                find.text('Offline. Showing the saved copy.'),
                findsOneWidget,
              );
              expect(find.text('Cached · 5 min old'), findsOneWidget);
              expect(find.textContaining('Updated '), findsOneWidget);
              expect(find.textContaining('SAST'), findsOneWidget);
          }

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));

          if (state == _HomeState.failure) {
            await tester.tap(find.text('Try again'));
            await tester.pumpAndSettle();

            expect(repository.calls, 2);
            expect(find.text('Test Savings'), findsOneWidget);
            expect(find.text('Reference: home-read-503'), findsNothing);
          }

          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
          await h.close(tester);
        }
      });
    }
  }
}

final class _HomeRepository implements HomeRepository {
  new(this._fetch);

  final Future<List<HomeEntry>> Function(int) _fetch;
  int calls = 0;

  @override
  Future<List<HomeEntry>> fetchHome(String userId) => _fetch(++calls);
}

final class _HomeHarness {
  new(this.database, this.session, this.events, this.controller, this.worker);

  final AppDatabase database;
  final TestSession session;
  final StreamController<CachedValue<List<HomeEntry>>?> events;
  final CacheController<List<HomeEntry>> controller;
  final PaymentWorker worker;

  static Future<_HomeHarness> pump(
    WidgetTester tester,
    _HomeRepository repository, {
    required bool cached,
  }) async {
    final database = memoryDatabase();
    final session = await TestSession.start();
    final events = StreamController<CachedValue<List<HomeEntry>>?>.broadcast(
      sync: true,
    );

    final controller = CacheController<List<HomeEntry>>(
      cache: events.stream,
      load: () => repository.fetchHome(testUserId),
      save: (value, generation, updatedAt) async {
        events.add(CachedValue(value: value, updatedAtUtc: updatedAt));
        return true;
      },
      remove: (_) async {
        events.add(null);
        return true;
      },
      generation: () => 0,
      isCurrent: () => true,
      clock: () => testNow,
    );

    final worker = PaymentWorker(
      store: PaymentOutbox(database),
      userId: testUserId,
      send: (_) async => const PaymentAccepted('unused-test-payment'),
      isCurrent: () => true,
      canSend: () => false,
      onResolved: (_) async {},
      clock: () => testNow,
    );

    final config = AppConfig.parse(
      nativeFlavor: 'dev',
      configuredFlavor: 'dev',
      apiBaseUrl: 'https://api.example.invalid',
    );

    if (cached) {
      events.add(
        CachedValue(
          value: [testHomeEntry],
          updatedAtUtc: testNow.subtract(const Duration(minutes: 5)),
        ),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(config),
          useApiRepositoriesProvider.overrideWith((_) => true),
          offlineEnabledProvider.overrideWithValue(true),
          offlineDatabaseProvider.overrideWithValue(database),
          offlineCacheClockProvider.overrideWithValue(() => testNow),
          sessionCoordinatorProvider.overrideWithValue(session.coordinator),
          homeRepositoryProvider.overrideWithValue(repository),
          cachedHomeProvider.overrideWith((_, _) => controller),
          paymentWorkerProvider.overrideWith((_, _) => worker),
        ],
        child: RondiTrackApp(config: config),
      ),
    );

    return _HomeHarness(database, session, events, controller, worker);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    worker.dispose();
    session.dispose();
    await events.close();
    await tester.runAsync(database.close);
  }
}
