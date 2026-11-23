import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/experimental/scope.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/app/provider_retry.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/config/auth_config.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/data/auth_api_provider.dart';
import 'package:ronditrack/core/session/data/secure_refresh_token_store.dart';
import 'package:ronditrack/core/session/refresh_token_store.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/activity/application/activity_provider.dart';
import 'package:ronditrack/features/auth/presentation/sign_in_screen.dart';
import 'package:ronditrack/features/auth/presentation/splash_screen.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/presentation/home_screen.dart';
import 'package:ronditrack/features/invites/application/invite_provider.dart';
import 'package:ronditrack/features/invites/domain/invite_repository.dart';
import 'package:ronditrack/features/payouts/application/payout_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_detail_screen.dart';

import 'support/account_flow_server.dart';

@Dependencies([Home, stokvelDetail, activityFeed, payoutOrder, homeRepository])
void main() {
  testWidgets('family phone disposes the old account and its caches', (
    tester,
  ) async {
    final server = AccountFlowServer();

    await _pump(tester, server);
    await _signIn(tester, 'lerato@ronditrack.co.za');

    final old = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
      listen: false,
    );

    final root = ProviderScope.containerOf(
      tester.element(find.byType(RondiTrackApp)),
      listen: false,
    );

    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));

    final held = <Object>[
      old.listen(homeProvider('lerato'), (_, _) {}),
      old.listen(stokvelDetailProvider('family-savers'), (_, _) {}),
      old.listen(
        stokvelDetailProvider('family-savers', cycleId: 'family-cycle-1'),
        (_, _) {},
      ),
      old.listen(activityFeedProvider('lerato'), (_, _) {}),
      old.listen(
        payoutOrderProvider((
          stokvelId: 'family-savers',
          cycleId: 'family-cycle-1',
        )),
        (_, _) {},
      ),
    ];

    await tester.pumpAndSettle();

    expect(held, hasLength(5));
    expect(old.exists(homeProvider('lerato')), isTrue);
    expect(root.exists(homeProvider('lerato')), isFalse);

    var wipedBeforeRemoteLogout = false;

    server.onLogout = () {
      try {
        old.read(homeProvider('lerato'));
      } on StateError {
        wipedBeforeRemoteLogout = true;
      }
    };

    router.go('/stokvels/family-savers');
    await tester.pumpAndSettle();

    expect(find.text('Close cycle'), findsOneWidget);

    router.go('/profile');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(wipedBeforeRemoteLogout, isTrue);

    expect(() => old.read(homeProvider('lerato')), throwsStateError);

    await _signIn(tester, 'naledi@ronditrack.co.za');

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('You have no stokvels yet.'), findsOneWidget);
    expect(find.text('Family Savers'), findsNothing);
    expect(find.text('Work Savers'), findsNothing);
    expect(find.text('Close cycle'), findsNothing);

    final next = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
      listen: false,
    );

    expect(identical(old, next), isFalse);
    expect(next.exists(homeProvider('lerato')), isFalse);
    expect(root.exists(homeProvider('lerato')), isFalse);

    router.go('/stokvels/family-savers');
    await tester.pumpAndSettle();

    expect(find.text('Not found'), findsOneWidget);
    expect(find.text('Close cycle'), findsNothing);
  });

  testWidgets('join survives sign-in Back rotation and token refresh', (
    tester,
  ) async {
    final server = AccountFlowServer();

    await _pump(tester, server, location: '/join/family-invite');
    await _signIn(tester, 'naledi@ronditrack.co.za');

    expect(find.byType(StokvelDetailScreen), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(server.joins, 1);

    final detail = tester.element(find.byType(StokvelDetailScreen));

    final router = GoRouter.of(detail);
    final container = ProviderScope.containerOf(detail, listen: false);

    await container.read(sessionCoordinatorProvider).refresh();

    router.go('/join/family-invite');
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1000, 550);
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    router.go('/join/family-invite');
    await tester.pumpAndSettle();

    expect(server.joins, 1);
    expect(server.previews, 1);
  });

  testWidgets('join survives registration without automatic sign-in', (
    tester,
  ) async {
    final server = AccountFlowServer();

    await _pump(tester, server, location: '/join/family-invite');

    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    for (final (key, value) in [
      ('register-name', 'New Member'),
      ('register-email', 'new@example.invalid'),
      ('register-phone', '0712345678'),
      ('register-password', 'typed-test-password'),
    ]) {
      final field = find.byKey(ValueKey(key));

      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await _tap(tester, 'register-submit');

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(server.joins, 0);

    await _signIn(tester, 'new@example.invalid');

    expect(server.registrations, 1);
    expect(server.joins, 1);
    expect(find.byType(StokvelDetailScreen), findsOneWidget);
  });

  testWidgets('cold join survives the restoring splash', (tester) async {
    final server = AccountFlowServer()..restoreGate = Completer<void>();

    await _pump(
      tester,
      server,
      location: '/join/family-invite',
      stored: true,
      settle: false,
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);

    server.restoreGate!.complete();
    await tester.pumpAndSettle();

    expect(server.joins, 1);
    expect(find.byType(StokvelDetailScreen), findsOneWidget);
  });

  testWidgets('existing member opens without a join POST', (tester) async {
    final server = AccountFlowServer();

    await _pump(tester, server, location: '/join/family-invite');
    await _signIn(tester, 'lerato@ronditrack.co.za');

    expect(find.text('Close cycle'), findsOneWidget);
    expect(server.joins, 0);
  });

  for (final (code, message) in [
    ('bad', 'This invite is not valid. Check the link or ask for a new one.'),
    ('expired', expiredInviteMessage),
  ]) {
    testWidgets('$code invite has a useful message', (tester) async {
      final server = AccountFlowServer();

      await _pump(tester, server, location: '/join/$code');
      await _signIn(tester, 'naledi@ronditrack.co.za');

      expect(find.text(message), findsOneWidget);
      expect(server.joins, 0);
    });
  }

  for (final conflict in [false, true]) {
    testWidgets('membership recovery avoids another POST conflict=$conflict', (
      tester,
    ) async {
      final server = AccountFlowServer()
        ..conflictOnJoin = conflict
        ..loseJoinResponse = !conflict;

      await _pump(tester, server, location: '/join/family-invite');
      await _signIn(tester, 'naledi@ronditrack.co.za');

      if (!conflict) {
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
      }

      expect(find.byType(StokvelDetailScreen), findsOneWidget);
      expect(server.joins, 1);
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  AccountFlowServer server, {
  String location = '/sign-in',
  bool stored = false,
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(550, 1000);

  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final dispatcher = tester.binding.platformDispatcher;
  dispatcher.defaultRouteNameTestValue = location;

  addTearDown(dispatcher.clearDefaultRouteNameTestValue);

  final config = AppConfig.parse(
    nativeFlavor: 'dev',
    configuredFlavor: 'dev',
    apiBaseUrl: 'https://api.example.invalid',
  );

  await tester.pumpWidget(
    ProviderScope(
      retry: appProviderRetry,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        authConfigProvider.overrideWithValue(
          AuthConfig.parse(
            refreshCookieName: 'configured_session',
            refreshCookiePath: '/api/v1/auth',
          ),
        ),
        useApiRepositoriesProvider.overrideWithValue(true),
        authApiProvider.overrideWithValue(server),
        refreshTokenStoreProvider.overrideWithValue(
          MemoryRefreshTokenStore(
            initialToken: stored ? const RefreshToken('stored-refresh') : null,
          ),
        ),
        homeRepositoryProvider.overrideWithValue(server.home),
        stokvelRepositoryProvider.overrideWithValue(server.stokvels),
        payoutRepositoryProvider.overrideWithValue(server.payouts),
        inviteRepositoryProvider.overrideWithValue(server),
      ],
      child: RondiTrackApp(config: config),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<void> _signIn(WidgetTester tester, String email) async {
  await tester.enterText(find.byKey(const ValueKey('sign-in-email')), email);
  await tester.enterText(
    find.byKey(const ValueKey('sign-in-password')),
    'typed-test-password',
  );

  await _tap(tester, 'sign-in-submit');
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));

  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}
