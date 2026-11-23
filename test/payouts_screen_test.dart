import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/experimental/scope.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/app/provider_retry.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/features/auth/presentation/sign_in_screen.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/payouts/application/payout_provider.dart';
import 'package:ronditrack/features/payouts/domain/payout_order.dart';
import 'package:ronditrack/features/payouts/domain/payout_repository.dart';
import 'package:ronditrack/features/payouts/presentation/payouts_screen.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/data/fake_stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_detail_screen.dart';

@Dependencies([payoutOrder, stokvelDetail, Home])
const _familyRoute = StokvelPayoutsRoute(
  id: 'family-savers',
  cycleId: 'family-cycle-1',
);
@Dependencies([payoutOrder, stokvelDetail, Home])
const _workRoute = StokvelPayoutsRoute(
  id: 'work-savers',
  cycleId: 'work-cycle-1',
);
const _stokvels = FakeStokvelRepository(delay: Duration.zero);

final _config = AppConfig.parse(
  nativeFlavor: 'dev',
  configuredFlavor: 'dev',
  apiBaseUrl: 'http://10.0.2.2:5227',
);

@Dependencies([payoutOrder, stokvelDetail, Home, homeRepository])
void main() {
  testWidgets(
    'resumes a cold payout link after sign-in and goes back to cycle',
    (tester) async {
      _setViewport(tester, const Size(550, 1000));
      _setLocation(tester, 'ronditrack-dev://app${_familyRoute.location}');

      await tester.pumpWidget(
        ProviderScope(
          retry: appProviderRetry,
          overrides: [stokvelRepositoryProvider.overrideWithValue(_stokvels)],
          child: RondiTrackApp(config: _config),
        ),
      );
      await tester.pumpAndSettle();

      final signIn = find.byType(SignInScreen);
      expect(signIn, findsOneWidget);
      final router = GoRouter.of(tester.element(signIn));
      expect(
        router.routeInformationProvider.value.uri.queryParameters['from'],
        _familyRoute.location,
      );

      await tester.enterText(find.byType(TextField), DemoPersona.lerato.email);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        _familyRoute.location,
      );
      expect(find.byType(PayoutsScreen), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(find.text('Next to be paid'), findsOneWidget);
      expect(find.text('R\u00A01\u00A0500,00'), findsWidgets);
      expect(
        tester.getTopLeft(find.text('1. Nandi')).dy,
        lessThan(tester.getTopLeft(find.text('2. Lerato')).dy),
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(StokvelCycleScreen), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        const StokvelCycleRoute(
          id: 'family-savers',
          cycleId: 'family-cycle-1',
        ).location,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'View payouts'));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        _familyRoute.location,
      );
    },
  );

  for (final (persona, route, label) in const [
    (DemoPersona.nandi, _familyRoute, 'Next to be paid'),
    (DemoPersona.lerato, _workRoute, 'No payout order yet.'),
    (DemoPersona.naledi, _familyRoute, 'Not found'),
  ]) {
    testWidgets('${persona.name} sees $label at ${route.location}', (
      tester,
    ) async {
      _setLocation(tester, route.location);

      await tester.pumpWidget(
        ProviderScope(
          retry: appProviderRetry,
          overrides: [
            demoSessionProvider.overrideWithBuild((_, _) => persona),
            stokvelRepositoryProvider.overrideWithValue(_stokvels),
          ],
          child: RondiTrackApp(config: _config),
        ),
      );
      await tester.pumpAndSettle();

      final screen = find.byType(PayoutsScreen);
      expect(screen, findsOneWidget);
      expect(
        find.descendant(of: screen, matching: find.text(label)),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Review payout'),
        findsNothing,
      );
      expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);
    });
  }

  testWidgets('shows loading and recovers when the user retries', (
    tester,
  ) async {
    _setLocation(tester, _familyRoute.location);
    final pending = Completer<PayoutOrder>();
    var requests = 0;
    final repository = _StubPayoutRepository((_, _) {
      requests += 1;
      if (requests == 1) {
        return pending.future;
      }

      return Future.value(
        const PayoutOrder(
          stokvelId: 'family-savers',
          cycleId: 'family-cycle-1',
          entries: [],
        ),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        retry: appProviderRetry,
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          stokvelRepositoryProvider.overrideWithValue(_stokvels),
          payoutRepositoryProvider.overrideWithValue(repository),
        ],
        child: RondiTrackApp(config: _config),
      ),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CircularProgressIndicator &&
            widget.semanticsLabel == 'Loading payout order',
      ),
      findsOneWidget,
    );

    pending.completeError(StateError('Offline'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load the payout order.'), findsOneWidget);
    final retry = find.widgetWithText(FilledButton, 'Retry');
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(find.text('No payout order yet.'), findsOneWidget);
  });

  testWidgets(
    'Treasurer can review at 360 by 640 with 200% text in dark mode',
    (tester) async {
      _setViewport(tester, const Size(360, 640));
      _setLocation(tester, _familyRoute.location);

      final dispatcher = tester.binding.platformDispatcher;
      dispatcher.textScaleFactorTestValue = 2;
      dispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(dispatcher.clearTextScaleFactorTestValue);
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        ProviderScope(
          retry: appProviderRetry,
          overrides: [
            demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
            stokvelRepositoryProvider.overrideWithValue(_stokvels),
          ],
          child: RondiTrackApp(config: _config),
        ),
      );
      await tester.pumpAndSettle();

      final screen = find.byType(PayoutsScreen);
      final context = tester.element(screen);
      expect(MediaQuery.textScalerOf(context).scale(16), 32);
      expect(Theme.of(context).brightness, Brightness.dark);

      final review = find.widgetWithText(OutlinedButton, 'Review payout');
      await tester.scrollUntilVisible(
        review,
        180,
        scrollable: find.descendant(
          of: screen,
          matching: find.byType(Scrollable),
        ),
      );
      expect(review.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(review);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Lerato\nR\u00A01\u00A0500,00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void _setLocation(WidgetTester tester, String location) {
  final dispatcher = tester.binding.platformDispatcher;
  dispatcher.defaultRouteNameTestValue = location;
  addTearDown(dispatcher.clearDefaultRouteNameTestValue);
}

final class _StubPayoutRepository implements PayoutRepository {
  const new(this._fetch);

  final Future<PayoutOrder> Function(String userId, PayoutCycleKey cycle)
  _fetch;

  @override
  Future<PayoutOrder> fetchOrder(String userId, PayoutCycleKey cycle) {
    return _fetch(userId, cycle);
  }
}
