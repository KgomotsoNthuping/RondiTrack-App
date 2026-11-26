import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/push/device_api.dart';
import 'package:ronditrack/core/push/device_session.dart';
import 'package:ronditrack/core/push/installation_messaging.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/refresh_token_store.dart';
import 'package:ronditrack/core/session/session_coordinator.dart';
import 'package:ronditrack/core/session/session_persistence.dart';

import '../support/assignment_12_1_fixtures.dart';

void main() {
  test('sign-in registers through the real coordinator', () async {
    final h = await _Harness.start();
    addTearDown(h.dispose);

    await h.api.firstRegistration.future.timeout(const Duration(seconds: 2));

    expect(h.coordinator.state, isA<AuthSignedIn>());
    expect(h.api.registrations, hasLength(1));
    expect(h.api.registrations.single.id, 'fid-one');
    expect(h.api.registrations.single.access.userId, testUserId);
    expect(h.api.registrations.single.access.value, 'signed-in');
  });

  test(
    'an online restored session registers with its refreshed access',
    () async {
      final h = await _Harness.start(restored: true);
      addTearDown(h.dispose);

      await h.api.firstRegistration.future.timeout(const Duration(seconds: 2));

      expect(h.api.registrations, hasLength(1));
      expect(h.api.registrations.single.access.value, 'restored');
      expect(h.api.registrations.single.access.userId, testUserId);
    },
  );

  test(
    'offline restoration attempts messaging and registers after recovery',
    () async {
      final h = await _Harness.start(restored: true, offline: true);
      addTearDown(h.dispose);

      await h.messaging.firstAttempt.future.timeout(const Duration(seconds: 2));
      await pumpEventQueue();

      expect(h.messaging.registerCalls, greaterThanOrEqualTo(1));
      expect(h.api.registrations, isEmpty);
      expect((h.coordinator.state as AuthSignedIn).isOffline, isTrue);

      when(() => h.auth.refresh(refreshToken: any(named: 'refreshToken')))
          .thenAnswer((_) async => Ok(_tokens(testUserId, 'recovered')));

      await h.coordinator.refresh();

      await h.api.firstRegistration.future.timeout(const Duration(seconds: 2));

      expect(h.api.registrations, hasLength(1));
      expect(h.api.registrations.single.access.value, 'recovered');
    },
  );

  test('a new installation id is registered again', () async {
    final h = await _Harness.start();
    addTearDown(h.dispose);

    await h.api.firstRegistration.future.timeout(const Duration(seconds: 2));

    h.messaging.emit('fid-new');
    await pumpEventQueue();

    expect(h.api.registrations.map((entry) => entry.id), [
      'fid-one',
      'fid-new',
    ]);
  });

  test(
    'a shared phone registers later ids only for its current account',
    () async {
      final h = await _Harness.start();
      addTearDown(h.dispose);

      await h.api.firstRegistration.future.timeout(const Duration(seconds: 2));
      await h.coordinator.signOut();

      const secondUser = '44444444-4444-4444-8444-444444444444';

      when(
        () => h.auth.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Ok(_tokens(secondUser, 'second-account')));

      await h.coordinator.signIn(
        email: 'second@example.invalid',
        password: 'test-only-password',
      );

      await pumpEventQueue();

      h.messaging.emit('fid-latest');
      await pumpEventQueue();

      expect(h.api.registrations, hasLength(3));
      expect(h.api.registrations.first.access.userId, testUserId);
      expect(h.api.registrations.skip(1).map((entry) => entry.access.userId), [
        secondUser,
        secondUser,
      ]);
    },
  );

  test('device deletion precedes session and credential clearing', () async {
    final h = await _Harness.start();
    addTearDown(h.dispose);

    await h.api.firstRegistration.future.timeout(const Duration(seconds: 2));

    h.api.forgetGate = Completer<void>();
    h.events.clear();

    h.coordinator.addListener(() {
      if (h.coordinator.state is AuthSignedOut) {
        h.events.add('session.signedOut');
      }
    });

    final exiting = h.coordinator.signOut();

    await h.api.firstForget.future.timeout(const Duration(seconds: 2));

    expect(h.coordinator.state, isA<AuthSignedIn>());
    expect(await h.store.read(), isNotNull);
    expect(h.persistence.identity, isNotNull);

    verifyNever(() => h.auth.logout(refreshToken: any(named: 'refreshToken')));

    h.api.forgetGate!.complete();

    expect(await exiting, isA<Ok<void>>());
    expect(h.api.forgotten.single.access.value, 'signed-in');
    expect(
      h.events.indexOf('device.delete'),
      lessThan(h.events.indexOf('session.signedOut')),
    );
    expect(
      h.events.indexOf('firebase.unregister'),
      lessThan(h.events.indexOf('session.signedOut')),
    );
    expect(
      h.events.indexOf('device.delete'),
      lessThan(h.events.indexOf('cache.clear')),
    );
    expect(await h.store.read(), isNull);
  });

  test('pending-payment protection still prevents deregistration', () async {
    final h = await _Harness.start(pending: true);
    addTearDown(h.dispose);

    await h.api.firstRegistration.future.timeout(const Duration(seconds: 2));

    expect(await h.coordinator.signOut(), isA<Err<void>>());
    expect(h.coordinator.state, isA<AuthSignedIn>());
    expect(h.api.forgotten, isEmpty);
    expect(h.messaging.unregisterCalls, 0);
  });

  test('Firebase failures cannot fail sign-in or sign-out', () async {
    final h = await _Harness.start(firebaseFails: true);
    addTearDown(h.dispose);

    await h.messaging.firstAttempt.future.timeout(const Duration(seconds: 2));
    await pumpEventQueue();

    expect(h.coordinator.state, isA<AuthSignedIn>());
    expect(h.api.registrations, isEmpty);
    expect(await h.coordinator.signOut(), isA<Ok<void>>());
    expect(h.coordinator.state, isA<AuthSignedOut>());
  });

  test(
    'API registration and deletion failures do not end the session early',
    () async {
      final h = await _Harness.start(apiFails: true);
      addTearDown(h.dispose);

      await h.api.firstRegistration.future.timeout(const Duration(seconds: 2));
      await pumpEventQueue();

      expect(h.coordinator.state, isA<AuthSignedIn>());
      expect(await h.coordinator.signOut(), isA<Ok<void>>());
      expect(h.coordinator.state, isA<AuthSignedOut>());
    },
  );

  testWidgets('sign-out stops waiting for Firebase after three seconds', (
    tester,
  ) async {
    final h = await _Harness.start();
    addTearDown(h.dispose);

    await tester.pump();
    expect(h.api.registrations, isNotEmpty);

    h.messaging.unregisterGate = Completer<void>();

    final exiting = h.coordinator.signOut();

    await tester.pump();

    expect(h.coordinator.state, isA<AuthSignedIn>());

    await tester.pump(const Duration(seconds: 2));

    expect(h.coordinator.state, isA<AuthSignedIn>());

    await tester.pump(const Duration(seconds: 2));

    expect(await exiting, isA<Ok<void>>());
    expect(h.coordinator.state, isA<AuthSignedOut>());

    const nextUser = '44444444-4444-4444-8444-444444444444';

    final previousRegistrations = h.messaging.registerCalls;

    when(
      () => h.auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Ok(_tokens(nextUser, 'after-timeout')));

    expect(
      await h.coordinator.signIn(
        email: 'next@example.invalid',
        password: 'test-only-password',
      ),
      isA<Ok<void>>(),
    );

    await tester.pump();

    expect(h.messaging.registerCalls, previousRegistrations);

    h.messaging.unregisterGate!.complete();
    await tester.pump();

    expect(h.api.registrations.last.access.userId, nextUser);
  });
}

AuthTokens _tokens(String userId, String value) => AuthTokens(
  accessToken: value,
  expiresAtUtc: testNow.add(const Duration(minutes: 10)),
  identity: AuthIdentity(userId: userId, email: 'synthetic@example.invalid'),
  refreshToken: RefreshToken('refresh-$value'),
);

final class _Harness {
  new(
    this.auth,
    this.messaging,
    this.api,
    this.devices,
    this.persistence,
    this.store,
    this.coordinator,
    this.events,
  );

  final MockAuthApi auth;
  final _Messaging messaging;
  final _DeviceApi api;
  final DeviceSession devices;
  final _Persistence persistence;
  final MemoryRefreshTokenStore store;
  final SessionCoordinator coordinator;
  final List<String> events;

  static Future<_Harness> start({
    bool restored = false,
    bool offline = false,
    bool pending = false,
    bool firebaseFails = false,
    bool apiFails = false,
  }) async {
    final events = <String>[];

    final messaging = _Messaging(events)..fails = firebaseFails;

    final api = _DeviceApi(events)..fails = apiFails;

    final devices = DeviceSession(
      messaging: messaging,
      api: api,
      clock: () => testNow,
    );

    final auth = MockAuthApi();

    when(() => auth.browserManagedCookies).thenReturn(false);

    when(
      () => auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Ok(_tokens(testUserId, 'signed-in')));

    when(() => auth.refresh(refreshToken: any(named: 'refreshToken')))
        .thenAnswer(
          (_) async => offline
              ? const Err<AuthTokens>(OfflineFailure(isRead: true))
              : Ok(_tokens(testUserId, 'restored')),
        );

    when(() => auth.logout(refreshToken: any(named: 'refreshToken')))
        .thenAnswer((_) async {
          events.add('auth.logout');
          return const Ok<void>(null);
        });

    final persistence = _Persistence(events)
      ..identity = restored ? testIdentity : null
      ..pending = pending;

    final store = MemoryRefreshTokenStore(
      initialToken: restored ? const RefreshToken('saved-refresh') : null,
    );

    final coordinator = SessionCoordinator(
      api: auth,
      refreshTokenStore: store,
      persistence: persistence,
      devices: devices,
      clock: () => testNow,
    );

    await coordinator.restore();

    if (!restored) {
      expect(
        await coordinator.signIn(
          email: 'synthetic@example.invalid',
          password: 'test-only-password',
        ),
        isA<Ok<void>>(),
      );
    }

    return _Harness(
      auth,
      messaging,
      api,
      devices,
      persistence,
      store,
      coordinator,
      events,
    );
  }

  Future<void> dispose() async {
    coordinator.dispose();
    devices.dispose();
    await messaging.close();
  }
}

final class _Messaging implements InstallationMessaging {
  new(this.events);

  final List<String> events;
  final _ids = StreamController<String>.broadcast(sync: true);

  final firstAttempt = Completer<void>();
  Completer<void>? unregisterGate;
  int registerCalls = 0;
  int unregisterCalls = 0;
  bool fails = false;

  @override
  bool get enabled => true;

  @override
  Stream<String> get onRegistered => _ids.stream;

  void emit(String id) => _ids.add(id);

  @override
  Future<void> register() async {
    registerCalls++;
    events.add('firebase.register');

    if (!firstAttempt.isCompleted) {
      firstAttempt.complete();
    }

    if (fails) {
      throw StateError('Synthetic Firebase failure.');
    }

    emit('fid-one');
  }

  @override
  Future<void> unregister() async {
    unregisterCalls++;
    events.add('firebase.unregister');

    await unregisterGate?.future;

    if (fails) {
      throw StateError('Synthetic Firebase failure.');
    }
  }

  Future<void> close() => _ids.close();
}

typedef _DeviceCall = ({String id, AccessToken access});

final class _DeviceApi implements DeviceApi {
  new(this.events);

  final List<String> events;
  final registrations = <_DeviceCall>[];
  final forgotten = <_DeviceCall>[];
  final firstRegistration = Completer<void>();
  final firstForget = Completer<void>();

  Completer<void>? forgetGate;
  bool fails = false;

  @override
  Future<bool> register(String id, AccessToken access) async {
    registrations.add((id: id, access: access));
    events.add('device.register');

    if (!firstRegistration.isCompleted) {
      firstRegistration.complete();
    }

    if (fails) {
      throw StateError('Synthetic API failure.');
    }

    return true;
  }

  @override
  Future<bool> forget(String id, AccessToken access) async {
    forgotten.add((id: id, access: access));
    events.add('device.delete');

    if (!firstForget.isCompleted) {
      firstForget.complete();
    }

    await forgetGate?.future;

    if (fails) {
      throw StateError('Synthetic API failure.');
    }

    return true;
  }

  @override
  void cancelPending() {}
}

final class _Persistence implements SessionPersistence {
  new(this.events);

  final List<String> events;
  AuthIdentity? identity;
  bool pending = false;

  @override
  Future<AuthIdentity?> readIdentity() async => identity;

  @override
  Future<void> rememberIdentity(AuthIdentity value) async {
    identity = value;
  }

  @override
  Future<bool> hasPendingPayments() async => pending;

  @override
  void invalidateWrites() => events.add('cache.invalidate');

  @override
  Future<void> clear() async {
    events.add('cache.clear');
    identity = null;
  }
}
