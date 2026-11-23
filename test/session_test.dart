import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/data/session_interceptor.dart';
import 'package:ronditrack/core/session/refresh_token_store.dart';
import 'package:ronditrack/core/session/session_coordinator.dart';
import 'package:ronditrack/core/session/sign_out_marker.dart';

import 'support/session_test_server.dart';

void main() {
  test('three expired-token requests share one refresh', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    await h.signIn();
    h.now = h.now.add(const Duration(minutes: 11));
    h.server.refreshGate = Completer<void>();

    final responses = Future.wait([
      h.dio.get<Object?>('/one'),
      h.dio.get<Object?>('/two'),
      h.dio.get<Object?>('/three'),
    ]);

    await h.server.refreshStarted.future;

    expect(h.server.refreshCalls, 1);
    h.server.refreshGate!.complete();

    expect(
      (await responses).map((value) => value.statusCode),
      everyElement(200),
    );
    expect(h.server.refreshCalls, 1);
    expect(h.server.requests, hasLength(3));
    expect(h.server.unauthorizedResponses, 0);
    expect(h.session.state, isA<AuthSignedIn>());
    expect((await h.store.read())?.value, h.server.currentRefresh);
  });

  test('three 401 responses share one refresh and retry once', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    await h.signIn();
    h.server.acceptedAccessOverride = 'spoiled-on-server';
    h.server.refreshGate = Completer<void>();

    final responses = Future.wait([
      h.dio.get<Object?>('/one'),
      h.dio.get<Object?>('/two'),
      h.dio.get<Object?>('/three'),
    ]);

    await h.server.refreshStarted.future;
    await h.server.waitForRequests(3);
    h.server.refreshGate!.complete();

    expect(
      (await responses).map((value) => value.statusCode),
      everyElement(200),
    );
    expect(h.server.refreshCalls, 1);
    expect(h.server.requests, hasLength(6));
    expect(h.server.revoked, isFalse);
  });

  test('a delayed old-token 401 reuses the replacement token', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    await h.signIn();

    h.server
      ..acceptedAccessOverride = 'spoiled-on-server'
      ..delayed401Path = '/slow'
      ..delayed401Gate = Completer<void>();

    final slow = h.dio.get<Object?>('/slow');

    await h.server.delayed401Started.future;

    expect((await h.dio.get<Object?>('/fast')).statusCode, 200);
    expect(h.server.refreshCalls, 1);

    h.server.delayed401Gate!.complete();

    expect((await slow).statusCode, 200);
    expect(h.server.refreshCalls, 1);
  });

  test('refreshes early without receiving a 401', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    await h.signIn();

    h.now = h.now.add(const Duration(minutes: 9, seconds: 40));

    expect((await h.dio.get<Object?>('/home')).statusCode, 200);
    expect(h.server.refreshCalls, 1);
    expect(h.server.unauthorizedResponses, 0);
  });

  test('a refused shared refresh ends the session once', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    await h.signIn();

    var signedOut = 0;

    h.session.addListener(() {
      if (h.session.state is AuthSignedOut) {
        signedOut++;
      }
    });

    h.server.revoked = true;

    final results = await Future.wait([
      h.session.refresh(),
      h.session.refresh(),
      h.session.refresh(),
    ]);

    expect(results, everyElement(isA<Err<AccessToken>>()));
    expect(h.server.refreshCalls, 1);
    expect(signedOut, 1);
    expect(h.session.state, isA<AuthSignedOut>());
    expect(await h.store.read(), isNull);
  });

  for (final failure in <Failure>[
    const ForbiddenFailure(),
    const RateLimitedFailure(retryAfterSeconds: 17),
    const ServerFailure(),
    const OfflineFailure(isRead: false),
  ]) {
    test('refresh ${failure.runtimeType} keeps the session', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.signIn();
      h.server.refreshFailure = failure;

      expect(await h.session.refresh(), isA<Err<AccessToken>>());
      expect(h.session.state, isA<AuthSignedIn>());
      expect(await h.store.read(), isNotNull);
      expect(h.server.logoutCalls, 0);
    });
  }

  for (final status in [403, 429, 500]) {
    test('HTTP $status does not refresh or sign out', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.signIn();
      h.server.protectedStatus = status;

      await expectLater(
        h.dio.get<Object?>('/home'),
        throwsA(isA<DioException>()),
      );

      expect(h.server.refreshCalls, 0);
      expect(h.session.state, isA<AuthSignedIn>());
    });
  }

  test('a second protected 401 stops after one retry', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    await h.signIn();
    h.server.protectedStatus = 401;

    await expectLater(
      h.dio.get<Object?>('/home'),
      throwsA(isA<DioException>()),
    );

    expect(h.server.requests, hasLength(2));
    expect(h.server.refreshCalls, 1);
    expect(h.session.state, isA<AuthSignedIn>());
  });

  test('restore without a stored token makes no refresh call', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    await h.session.restore();

    expect(h.session.state, isA<AuthSignedOut>());
    expect(h.server.refreshCalls, 0);
  });

  test('restore rotates a good stored token once', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    await h.store.write(const RefreshToken('refresh-0'));

    await Future.wait([h.session.restore(), h.session.restore()]);

    expect(h.session.state, isA<AuthSignedIn>());
    expect(h.server.refreshCalls, 1);
    expect((await h.store.read())?.value, 'refresh-1');
  });

  test('restore clears a refused stored token', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    await h.store.write(const RefreshToken('refresh-0'));
    h.server.revoked = true;

    await h.session.restore();

    expect(h.session.state, isA<AuthSignedOut>());
    expect(await h.store.read(), isNull);
  });

  test('offline restore retains credentials and can be retried', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    await h.store.write(const RefreshToken('refresh-0'));

    h.server.refreshFailure = const OfflineFailure(isRead: false);

    await h.session.restore();

    expect(
      h.session.state,
      isA<AuthRestoring>().having(
        (value) => value.failure,
        'failure',
        isA<OfflineFailure>(),
      ),
    );
    expect((await h.store.read())?.value, 'refresh-0');

    h.server.refreshFailure = null;
    await h.session.restore();

    expect(h.session.state, isA<AuthSignedIn>());
  });

  for (final offline in [false, true]) {
    test('sign-out clears credentials with offline=$offline', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.signIn();

      if (offline) {
        h.server.logoutFailure = const OfflineFailure(isRead: false);
      }

      final finished = h.session.signOut();

      expect(h.session.state, isA<AuthSignedOut>());
      expect(await finished, isA<Ok<void>>());
      expect(await h.store.read(), isNull);
      expect(await h.marker.read(), isTrue);
      expect(h.server.logoutCalls, 1);
    });
  }

  test('a refresh finishing after sign-out is ignored', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    await h.signIn();
    h.server.refreshGate = Completer<void>();

    final late = h.session.refresh();

    await h.server.refreshStarted.future;
    await h.session.signOut();

    h.server.refreshGate!.complete();

    expect(await late, isA<Err<AccessToken>>());
    expect(h.session.state, isA<AuthSignedOut>());
    expect(await h.store.read(), isNull);
  });

  test('sign-out erases a refresh write already in progress', () async {
    final store = _SlowStore();
    final h = _Harness(store: store);

    addTearDown(h.dispose);
    addTearDown(() {
      if (!store.release.isCompleted) {
        store.release.complete();
      }
    });

    await h.signIn();

    store.block = true;
    final late = h.session.refresh();

    await store.started.future;

    final finished = h.session.signOut();

    expect(h.session.state, isA<AuthSignedOut>());

    store.release.complete();

    await finished;

    expect(await late, isA<Err<AccessToken>>());
    expect(await store.read(), isNull);
  });

  test('browser offline sign-out blocks restoration on restart', () async {
    final h = _Harness(browser: true);
    addTearDown(h.dispose);

    await h.session.restore();

    h.server.logoutFailure = const OfflineFailure(isRead: false);

    await h.session.signOut();

    final before = h.server.refreshCalls;

    final restarted = SessionCoordinator(
      api: h.server,
      signOutMarker: h.marker,
      clock: () => h.now,
    );

    addTearDown(restarted.dispose);

    await restarted.restore();

    expect(restarted.state, isA<AuthSignedOut>());
    expect(h.server.refreshCalls, before);
  });

  test('spent-token reuse revokes the fake token family', () async {
    final server = RotatingAuthServer(clock: () => DateTime.utc(2026, 11, 19));

    final first = await server.refresh(
      refreshToken: const RefreshToken('refresh-0'),
    );

    expect(first, isA<Ok<AuthTokens>>());

    final replacement = (first as Ok<AuthTokens>).value.refreshToken;

    expect(
      await server.refresh(refreshToken: const RefreshToken('refresh-0')),
      isA<Err<AuthTokens>>(),
    );
    expect(server.revoked, isTrue);

    expect(
      await server.refresh(refreshToken: replacement),
      isA<Err<AuthTokens>>(),
    );
  });
}

final class _Harness {
  new({RefreshTokenStore? store, bool browser = false}) {
    this.store = store ?? MemoryRefreshTokenStore();

    server = RotatingAuthServer(
      clock: () => now,
      browserManagedCookies: browser,
    );

    session = SessionCoordinator(
      api: server,
      refreshTokenStore: browser ? null : this.store,
      signOutMarker: marker,
      clock: () => now,
    );

    retry = Dio(BaseOptions(baseUrl: 'http://localhost:5227'))
      ..httpClientAdapter = server;

    dio = Dio(BaseOptions(baseUrl: 'http://localhost:5227'))
      ..httpClientAdapter = server
      ..interceptors.add(SessionInterceptor(session: session, retryDio: retry));
  }

  DateTime now = DateTime.utc(2026, 11, 19);
  final marker = MemorySignOutMarker();

  late final RefreshTokenStore store;
  late final RotatingAuthServer server;
  late final SessionCoordinator session;
  late final Dio retry;
  late final Dio dio;

  Future<void> signIn() async {
    await session.restore();

    expect(
      await session.signIn(
        email: 'member@example.invalid',
        password: 'typed-test-password',
      ),
      isA<Ok<void>>(),
    );

    expect(await store.read(), isNotNull);
  }

  void dispose() {
    session.dispose();
    dio.close(force: true);
    retry.close(force: true);

    final refreshGate = server.refreshGate;

    if (refreshGate != null && !refreshGate.isCompleted) {
      refreshGate.complete();
    }

    final delayedGate = server.delayed401Gate;

    if (delayedGate != null && !delayedGate.isCompleted) {
      delayedGate.complete();
    }
  }
}

final class _SlowStore implements RefreshTokenStore {
  final _inner = MemoryRefreshTokenStore();
  final started = Completer<void>();
  final release = Completer<void>();
  bool block = false;

  @override
  Future<RefreshToken?> read() => _inner.read();

  @override
  Future<void> write(RefreshToken token) async {
    if (block) {
      if (!started.isCompleted) {
        started.complete();
      }

      await release.future;
    }

    await _inner.write(token);
  }

  @override
  Future<void> clear() => _inner.clear();
}
