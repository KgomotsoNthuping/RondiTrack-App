import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/app/navigation/auth_redirect.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/config/auth_config.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_api.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/data/auth_api_provider.dart';
import 'package:ronditrack/core/session/data/secure_refresh_token_store.dart';
import 'package:ronditrack/core/session/refresh_token_store.dart';
import 'package:ronditrack/features/auth/application/auth_form_state.dart';
import 'package:ronditrack/features/auth/presentation/register_screen.dart';
import 'package:ronditrack/features/auth/presentation/sign_in_screen.dart';
import 'package:ronditrack/features/auth/presentation/splash_screen.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/data/fake_home_repository.dart';
import 'package:ronditrack/features/profile/presentation/profile_screen.dart';

void main() {
  test('protected addresses wait at splash and keep their destination', () {
    for (final target in [
      '/',
      '/stokvels',
      '/stokvels/one',
      '/activity',
      '/profile',
      '/join/code',
    ]) {
      final splash = Uri.parse(
        authRedirect(
          location: Uri.parse(target),
          signedIn: false,
          restoring: true,
        )!,
      );

      expect(splash.path, splashPath);
      expect(authRedirect(location: splash, signedIn: true), target);
    }

    final splash = Uri.parse(
      authRedirect(
        location: Uri.parse('/register?from=%2Fprofile'),
        signedIn: false,
        restoring: true,
      )!,
    );

    expect(
      Uri.parse(authRedirect(location: splash, signedIn: false)!).path,
      registerPath,
    );
  });

  for (final flavor in AppFlavor.values) {
    testWidgets('${flavor.name} offers password sign-in and registration', (
      tester,
    ) async {
      await _pump(tester, _FormApi(), flavor: flavor);

      expect(find.byKey(const ValueKey('sign-in-password')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dev-email-picker')),
        flavor == AppFlavor.dev ? findsOneWidget : findsNothing,
      );

      await tester.ensureVisible(find.text('Create an account'));
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  }

  testWidgets('wrong password has one generic message', (tester) async {
    final api = _FormApi()..loginFailure = const UnauthorizedFailure();

    await _pump(tester, api);
    await _loginFields(tester);
    await _tap(tester, 'sign-in-submit');

    expect(find.text('The email and password do not match.'), findsOneWidget);
    expect(api.loginCalls, 1);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('the dev picker fills only the email', (tester) async {
    final api = _FormApi();

    await _pump(tester, api);

    await tester.tap(find.byKey(const ValueKey('dev-email-picker')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nandi').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('sign-in-email')))
          .controller!
          .text,
      'nandi@ronditrack.co.za',
    );

    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('sign-in-password')))
          .controller!
          .text,
      isEmpty,
    );

    expect(api.loginCalls, 0);
  });

  testWidgets('429 disables submission and survives navigation', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 19);

    final api = _FormApi()
      ..loginFailure = const RateLimitedFailure(retryAfterSeconds: 17);

    await _pump(tester, api, clock: () => now);
    await _loginFields(tester);
    await _tap(tester, 'sign-in-submit');

    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('sign-in-submit')))
          .onPressed,
      isNull,
    );
    expect(find.text('Try again in 17s'), findsOneWidget);

    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    final back = find.text('Already have an account? Sign in');

    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('sign-in-submit')))
          .onPressed,
      isNull,
    );

    now = now.add(const Duration(seconds: 17));
    await tester.pump(const Duration(seconds: 17));

    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('sign-in-submit')))
          .onPressed,
      isNotNull,
    );
    expect(api.loginCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('registration puts server errors under their fields', (
    tester,
  ) async {
    final api = _FormApi()
      ..registrationFailure = ValidationFailure(
        errors: const {
          'FullName': ['Use your full name.'],
          'Email': ['Use a valid address.'],
          'PhoneNumber': ['Use a valid number.'],
          'Password': ['Choose a stronger password.'],
        },
      );

    await _pump(tester, api, location: '/register');
    await _registerFields(tester);
    await _tap(tester, 'register-submit');

    for (final message in [
      'Use your full name.',
      'Use a valid address.',
      'Use a valid number.',
      'Choose a stronger password.',
    ]) {
      expect(find.text(message), findsOneWidget);
    }

    expect(api.registerCalls, 1);
  });

  testWidgets('duplicate registration identifies the email field', (
    tester,
  ) async {
    final api = _FormApi()..registrationFailure = const ConflictFailure();

    await _pump(tester, api, location: '/register');
    await _registerFields(tester);
    await _tap(tester, 'register-submit');

    expect(
      find.text('An account with this email already exists.'),
      findsOneWidget,
    );
  });

  testWidgets('registration returns to sign-in and keeps the destination', (
    tester,
  ) async {
    final api = _FormApi();

    await _pump(tester, api, location: '/register?from=%2Fprofile');
    await _registerFields(tester);
    await _tap(tester, 'register-submit');

    expect(find.byType(SignInScreen), findsOneWidget);

    final email = tester.widget<TextFormField>(
      find.byKey(const ValueKey('sign-in-email')),
    );

    expect(email.controller!.text, 'new@example.invalid');
    expect(api.loginCalls, 0);

    await tester.enterText(
      find.byKey(const ValueKey('sign-in-password')),
      'typed-test-password',
    );
    await _tap(tester, 'sign-in-submit');

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('new@example.invalid'), findsOneWidget);
  });

  testWidgets('cold restore shows splash then the requested profile', (
    tester,
  ) async {
    final api = _FormApi()..refreshReply = Completer<Result<AuthTokens>>();

    await _pump(tester, api, location: '/profile', stored: true, settle: false);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);

    api.refreshReply!.complete(Ok(_tokens()));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('offline splash offers retry and keeps credentials', (
    tester,
  ) async {
    final api = _FormApi()
      ..restoreFailure = const OfflineFailure(isRead: false);

    final store = await _pump(tester, api, location: '/profile', stored: true);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(await store.read(), isNotNull);

    api.restoreFailure = null;

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}

Future<MemoryRefreshTokenStore> _pump(
  WidgetTester tester,
  _FormApi api, {
  AppFlavor flavor = AppFlavor.dev,
  String location = '/sign-in',
  bool stored = false,
  bool settle = true,
  DateTime Function()? clock,
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
    nativeFlavor: flavor.name,
    configuredFlavor: flavor.name,
    apiBaseUrl: 'https://api.example.invalid',
  );

  final store = MemoryRefreshTokenStore(
    initialToken: stored ? const RefreshToken('stored-refresh') : null,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        authConfigProvider.overrideWithValue(
          AuthConfig.parse(
            refreshCookieName: 'configured_session',
            refreshCookiePath: '/api/v1/auth',
          ),
        ),
        useApiRepositoriesProvider.overrideWithValue(true),
        authApiProvider.overrideWithValue(api),
        refreshTokenStoreProvider.overrideWithValue(store),
        authFormClockProvider.overrideWithValue(clock ?? DateTime.now),
        homeRepositoryProvider.overrideWithValue(
          const FakeHomeRepository(delay: Duration.zero),
        ),
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

  return store;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));

  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _loginFields(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('sign-in-email')),
    'new@example.invalid',
  );
  await tester.enterText(
    find.byKey(const ValueKey('sign-in-password')),
    'typed-test-password',
  );
}

Future<void> _registerFields(WidgetTester tester) async {
  for (final (key, value) in [
    ('register-name', 'New Member'),
    ('register-email', 'new@example.invalid'),
    ('register-phone', '0712345678'),
    ('register-password', 'typed-test-password'),
  ]) {
    final finder = find.byKey(ValueKey(key));

    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
  }
}

AuthTokens _tokens() {
  return AuthTokens(
    accessToken: 'ui-test-access',
    expiresAtUtc: DateTime.utc(2099),
    identity: const AuthIdentity(
      userId: 'new-account-id',
      email: 'new@example.invalid',
    ),
    refreshToken: const RefreshToken('ui-test-refresh'),
  );
}

final class _FormApi implements AuthApi {
  Failure? loginFailure;
  Failure? registrationFailure;
  Failure? restoreFailure;
  Completer<Result<AuthTokens>>? refreshReply;

  int loginCalls = 0;
  int registerCalls = 0;

  @override
  bool get browserManagedCookies => false;

  @override
  Future<Result<AuthTokens>> signIn({
    required String email,
    required String password,
  }) async {
    loginCalls++;

    return loginFailure == null ? Ok(_tokens()) : Err(loginFailure!);
  }

  @override
  Future<Result<RegisteredAccount>> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    registerCalls++;

    return registrationFailure == null
        ? Ok(
            RegisteredAccount(
              userId: 'new-account-id',
              fullName: fullName,
              email: email,
              phoneNumber: phoneNumber,
              version: 1,
            ),
          )
        : Err(registrationFailure!);
  }

  @override
  Future<Result<AuthTokens>> refresh({RefreshToken? refreshToken}) async {
    if (refreshReply case final reply?) {
      return reply.future;
    }

    return restoreFailure == null ? Ok(_tokens()) : Err(restoreFailure!);
  }

  @override
  Future<Result<void>> logout({RefreshToken? refreshToken}) async {
    return const Ok(null);
  }

  @override
  void cancelPending() {}
}
