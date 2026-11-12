import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/layout/window_size.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/data/fake_home_repository.dart';
import 'package:ronditrack/features/home/presentation/home_stokvel_card.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/data/fake_stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_detail_screen.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvels_screen.dart';

const _homeFixtures = FakeHomeRepository(delay: Duration.zero);
const _stokvelFixtures = FakeStokvelRepository(delay: Duration.zero);

final _config = AppConfig.parse(
  nativeFlavor: 'dev',
  configuredFlavor: 'dev',
  apiBaseUrl: 'http://10.0.2.2:5227',
);

void main() {
  test('classifies window widths at both breakpoints', () {
    expect(WindowSize.fromWidth(599), WindowSize.compact);
    expect(WindowSize.fromWidth(600), WindowSize.medium);
    expect(WindowSize.fromWidth(839), WindowSize.medium);
    expect(WindowSize.fromWidth(840), WindowSize.expanded);
  });

  testWidgets('opens each tab at its address', (tester) async {
    _setViewport(tester, const Size(550, 1100));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(_homeFixtures),
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
        expect(find.text('Work Savers'), findsWidgets);
      }
    }

    expect(find.text('Family Savers'), findsOneWidget);
    expect(find.text('Work Savers'), findsOneWidget);
  });

  testWidgets(
    'remembers a protected address through sign-in and clears it on sign-out',
    (tester) async {
      _setViewport(tester, const Size(550, 1100));
      final location = const StokvelDetailRoute(id: 'family-savers').location;
      _setInitialLocation(tester, location);

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

      final signIn = find.widgetWithText(FilledButton, 'Sign in');
      final email = find.byType(TextField);
      expect(signIn, findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.enterText(email, 'unknown@example.com');
      await tester.tap(signIn);
      await tester.pumpAndSettle();
      expect(find.text('Enter a recognised demo email.'), findsOneWidget);

      await tester.enterText(email, 'nandi@ronditrack.co.za');
      await tester.tap(signIn);
      await tester.pumpAndSettle();

      final detail = find.byType(StokvelDetailScreen);
      final router = GoRouter.of(tester.element(detail));
      expect(router.routeInformationProvider.value.uri.path, location);
      expect(find.text('Family Savers'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Close cycle'), findsNothing);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/profile');
      expect(find.text('nandi@ronditrack.co.za'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      final signedOutRouter = GoRouter.of(tester.element(signIn));
      expect(signedOutRouter.routeInformationProvider.value.uri.path, '/sign-in');
      expect(signedOutRouter.canPop(), isFalse);
      expect(detail, findsNothing);

      signedOutRouter.go(location);
      await tester.pumpAndSettle();

      expect(signedOutRouter.routeInformationProvider.value.uri.path, '/sign-in');
      expect(signIn, findsOneWidget);
      expect(detail, findsNothing);
    },
  );

  testWidgets('Home, list and detail work at 360 by 640 with 200% text', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 640));
    final dispatcher = tester.binding.platformDispatcher;
    dispatcher.textScaleFactorTestValue = 2;
    addTearDown(dispatcher.clearTextScaleFactorTestValue);

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

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    final card = find.byType(HomeStokvelCard).first;
    final scaler = MediaQuery.textScalerOf(tester.element(card));
    expect(scaler.scale(20), 40);

    final paid = find.descendant(
      of: card,
      matching: find.text('Paid this cycle'),
    );
    final owed = find.descendant(
      of: card,
      matching: find.text('Still owed'),
    );
    expect(tester.getTopLeft(owed).dy, greaterThan(tester.getTopLeft(paid).dy));

    await tester.scrollUntilVisible(
      find.text('Work Savers'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Stokvels'));
    await tester.pumpAndSettle();

    final familyTile = find.widgetWithText(ListTile, 'Family Savers');
    expect(familyTile, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(familyTile);
    await tester.pumpAndSettle();

    expect(find.byType(StokvelDetailScreen), findsOneWidget);
    expect(find.byType(StokvelListPane), findsNothing);
    expect(find.text('Family Savers'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Close cycle'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final viewCycle = find.widgetWithText(FilledButton, 'View cycle');
    await tester.ensureVisible(viewCycle);
    await tester.pumpAndSettle();
    expect(viewCycle.hitTestable(), findsOneWidget);

    await tester.tap(viewCycle);
    await tester.pumpAndSettle();
    expect(find.byType(StokvelCycleScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape shows both panes and portrait keeps the selected ID', (
    tester,
  ) async {
    _setViewport(tester, const Size(1100, 800));
    final familyLocation = const StokvelDetailRoute(id: 'family-savers').location;
    final workLocation = const StokvelDetailRoute(id: 'work-savers').location;
    _setInitialLocation(tester, familyLocation);

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

    final detail = find.byType(StokvelDetailScreen);
    final list = find.byType(StokvelListPane);
    final rail = find.byType(NavigationRail);
    final router = GoRouter.of(tester.element(detail));

    expect(router.routeInformationProvider.value.uri.path, familyLocation);
    expect(rail, findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(list, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Close cycle')).dx,
      greaterThan(tester.getBottomRight(list).dx),
    );
    expect(tester.takeException(), isNull);

    final workTile = find.widgetWithText(ListTile, 'Work Savers');
    await tester.tap(workTile);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, workLocation);
    expect(tester.widget<ListTile>(workTile).selected, isTrue);
    expect(find.text('Upload proof'), findsOneWidget);
    expect(find.text('Close cycle'), findsNothing);

    tester.view.physicalSize = const Size(800, 1100);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, workLocation);
    expect(detail, findsOneWidget);
    expect(list, findsNothing);
    expect(rail, findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/stokvels');
    expect(find.byType(StokvelsScreen), findsOneWidget);
    expect(list, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setInitialLocation(WidgetTester tester, String location) {
  final dispatcher = tester.binding.platformDispatcher;
  dispatcher.defaultRouteNameTestValue = location;
  addTearDown(dispatcher.clearDefaultRouteNameTestValue);
}