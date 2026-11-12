import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/features/auth/presentation/sign_in_screen.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/data/fake_home_repository.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/data/fake_stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_detail_screen.dart';

const _homeFixtures = FakeHomeRepository(delay: Duration.zero);
const _stokvelFixtures = FakeStokvelRepository(delay: Duration.zero);

final _config = AppConfig.parse(
  nativeFlavor: 'dev',
  configuredFlavor: 'dev',
  apiBaseUrl: 'http://10.0.2.2:5227',
);

void main() {
  testWidgets('opens each tab at its address', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(_homeFixtures),
          stokvelRepositoryProvider.overrideWithValue(_stokvelFixtures),
        ],
        child: RondiTrackApp(config: _config),
      ),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('RondiTrack')));
    expect(router.routeInformationProvider.value.uri.path, '/');

    for (final (label, path) in const [
      ('Stokvels', '/stokvels'),
      ('Activity', '/activity'),
      ('Profile', '/profile'),
      ('Home', '/'),
    ]) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);

      if (label == 'Activity') {
        expect(find.text('Family Savers'), findsWidgets);
        expect(find.text('Work Savers'), findsOneWidget);
      }
    }

    expect(find.text('Family Savers'), findsOneWidget);
    expect(find.text('Work Savers'), findsOneWidget);
  });

  testWidgets('resumes a stokvel address and clears the stack on sign-out', (
    tester,
  ) async {
    const detail = StokvelDetailRoute(id: 'family-savers');
    final dispatcher = tester.binding.platformDispatcher;
    dispatcher.defaultRouteNameTestValue = detail.location;
    addTearDown(dispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeRepositoryProvider.overrideWithValue(_homeFixtures),
          stokvelRepositoryProvider.overrideWithValue(_stokvelFixtures),
        ],
        child: RondiTrackApp(config: _config),
      ),
    );
    await tester.pumpAndSettle();

    final signIn = find.byType(SignInScreen);
    final router = GoRouter.of(tester.element(signIn));
    final signInButton = find.widgetWithText(FilledButton, 'Sign in');

    expect(router.routeInformationProvider.value.uri.path, '/sign-in');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['from'],
      detail.location,
    );

    await tester.enterText(find.byType(TextField), 'unknown@example.test');
    await tester.tap(signInButton);
    await tester.pumpAndSettle();
    expect(find.text('Enter a recognised demo email.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' Nandi@ronditrack.co.za ');
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(find.byType(StokvelDetailScreen), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, detail.location);
    expect(find.text('Member'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    expect(find.text('nandi@ronditrack.co.za'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(router.canPop(), isFalse);

    router.go(detail.location);
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(StokvelDetailScreen), findsNothing);
  });
}