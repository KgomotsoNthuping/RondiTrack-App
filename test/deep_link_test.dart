import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/app/navigation/auth_redirect.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/features/auth/presentation/sign_in_screen.dart';
import 'package:ronditrack/features/invites/presentation/invite_preview_screen.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_detail_screen.dart';

final _config = AppConfig.parse(
  nativeFlavor: 'dev',
  configuredFlavor: 'dev',
  apiBaseUrl: 'http://10.0.2.2:5227',
);

void main() {
  test('remembers a native invite for the matching flavour', () {
    for (final flavor in AppFlavor.values) {
      final scheme = 'ronditrack-${flavor.name}';
      final location = Uri.parse('$scheme://app/join/family-invite');
      final signIn = Uri.parse(
        authRedirect(
          location: location,
          signedIn: false,
          appLinkScheme: scheme,
        )!,
      );

      expect(signIn.path, signInPath);
      expect(signIn.queryParameters['from'], '/join/family-invite');
      expect(
        authRedirect(
          location: signIn,
          signedIn: true,
          appLinkScheme: scheme,
        ),
        '/join/family-invite',
      );
    }
  });

  test('drops a link aimed at a different flavour', () {
    expect(
      authRedirect(
        location: Uri.parse('ronditrack-staging://app/join/family-invite'),
        signedIn: false,
        appLinkScheme: 'ronditrack-dev',
      ),
      signInPath,
    );
  });

  testWidgets('resumes a cold invite and joins as a member', (tester) async {
    _setInitialLink(tester, 'ronditrack-dev://app/join/family-invite');

    await tester.pumpWidget(
      ProviderScope(child: RondiTrackApp(config: _config)),
    );
    await tester.pumpAndSettle();

    final signIn = find.byType(SignInScreen);
    final router = GoRouter.of(tester.element(signIn));

    expect(
      router.routeInformationProvider.value.uri.queryParameters['from'],
      '/join/family-invite',
    );

    await tester.enterText(find.byType(TextField), 'naledi@ronditrack.co.za');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(InvitePreviewScreen), findsOneWidget);
    expect(find.text('Family Savers'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Join stokvel'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/stokvels/family-savers');
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Close cycle'), findsNothing);

    const HomeRoute().go(
      tester.element(find.byType(StokvelDetailScreen)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Signed in as Naledi'), findsOneWidget);
    expect(find.text('Family Savers'), findsOneWidget);
  });

  testWidgets('opens a warm link with the role for that stokvel', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    _setInitialLink(tester, 'ronditrack-dev://app/stokvels/family-savers');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
        ],
        child: RondiTrackApp(config: _config),
      ),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(StokvelDetailScreen)));
    expect(find.text('Close cycle'), findsOneWidget);

    await router.routeInformationProvider.didPushRouteInformation(
      RouteInformation(
        uri: Uri.parse('ronditrack-dev://app/stokvels/work-savers'),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/stokvels/work-savers');
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Close cycle'), findsNothing);
  });

  for (final path in [
    '/stokvels/family-savers',
    '/stokvels/family-savers/cycles/family-cycle-1',
  ]) {
    testWidgets('shows not found for a non-member at $path', (tester) async {
      _setInitialLink(tester, 'ronditrack-dev://app$path');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.naledi),
          ],
          child: RondiTrackApp(config: _config),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not found'), findsOneWidget);
      expect(find.text('Contributions'), findsNothing);
    });
  }
}

void _setInitialLink(WidgetTester tester, String link) {
  final dispatcher = tester.binding.platformDispatcher;
  dispatcher.defaultRouteNameTestValue = link;
  addTearDown(dispatcher.clearDefaultRouteNameTestValue);
}