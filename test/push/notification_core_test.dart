import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/push/data/android_local_notifications.dart';
import 'package:ronditrack/core/push/notification_permission.dart';
import 'package:ronditrack/core/push/push_runtime.dart';
import 'package:ronditrack/core/push/push_target.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/data/secure_refresh_token_store.dart';

import '../support/assignment_12_1_fixtures.dart';
import '../support/notification_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('payload produces only the approved cycle address and keys', () {
    final target = PushTarget.parse(pushData)!;

    expect(target.location, '/stokvels/$testStokvelId/cycles/$testCycleId');
    expect(target.data, pushData);
    expect(PushTarget.decode(target.payload)!.location, target.location);
    expect(AndroidLocalNotifications.title, 'RondiTrack');
    expect(
      AndroidLocalNotifications.body,
      "There's an update on your stokvel.",
    );
  });

  test(
    'rejects unknown fields, types, non-UUID ids and injected addresses',
    () {
      final invalid = <Object?>[
        null,
        [],
        {...pushData, 'type': 'payment_confirmed'},
        {...pushData, 'amount': 45000},
        {...pushData}..remove('cycleId'),
        {...pushData, 'stokvelId': 123},
        for (final value in [
          '',
          'ordinary-id',
          '../profile',
          'https://example.invalid',
          '$testCycleId?edit=true',
          '$testCycleId/../profile',
          '%2Fprofile',
          '$testCycleId\n',
        ])
          {...pushData, 'cycleId': value},
      ];

      for (final data in invalid) {
        expect(PushTarget.parse(data), isNull, reason: '$data');
      }

      expect(PushTarget.decode('not json'), isNull);
      expect(PushTarget.decode('[]'), isNull);
    },
  );

  test('UUIDs are normalized before forming the route', () {
    final data = {
      ...pushData,
      'stokvelId': 'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA',
    };

    expect(
      PushTarget.parse(data)!.stokvelId,
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
  });

  test('first payment explains before the OS request', () async {
    final local = TestLocalNotifications()..requestResult = true;

    final preferences = TestNotificationPreferences();

    addTearDown(local.close);

    final permission = NotificationPermission(
      enabled: true,
      notifications: local,
      preferences: preferences,
    );

    expect(local.requests, 0);
    expect(preferences.reads, 0);

    final outcome = await permission.afterPayment(
      explain: () async {
        expect(preferences.value, isTrue);
        local.events.add('explain');
        return true;
      },
      isCurrent: () => true,
    );

    expect(outcome, PermissionOutcome.granted);
    expect(local.events, ['explain', 'request']);
  });

  test(
    'Not now survives a new controller and never requests Android',
    () async {
      final local = TestLocalNotifications();
      final preferences = TestNotificationPreferences();

      addTearDown(local.close);

      var explanations = 0;

      Future<bool> explain() async {
        explanations++;
        return false;
      }

      for (var launch = 0; launch < 2; launch++) {
        await NotificationPermission(
          enabled: true,
          notifications: local,
          preferences: preferences,
        ).afterPayment(explain: explain, isCurrent: () => true);
      }

      expect(explanations, 1);
      expect(preferences.writes, 1);
      expect(local.requests, 0);
    },
  );

  test('Android denial is remembered without another OS request', () async {
    final local = TestLocalNotifications();
    final preferences = TestNotificationPreferences();

    addTearDown(local.close);

    for (var launch = 0; launch < 2; launch++) {
      await NotificationPermission(
        enabled: true,
        notifications: local,
        preferences: preferences,
      ).afterPayment(explain: () async => true, isCurrent: () => true);
    }

    expect(local.requests, 1);
  });

  test('push off touches neither the preferences nor Android', () async {
    final local = TestLocalNotifications();
    final preferences = TestNotificationPreferences();

    addTearDown(local.close);

    final outcome =
        await NotificationPermission(
          enabled: false,
          notifications: local,
          preferences: preferences,
        ).afterPayment(
          explain: () => throw StateError('Should not explain'),
          isCurrent: () => true,
        );

    expect(outcome, PermissionOutcome.disabled);
    expect(preferences.reads, 0);
    expect(local.checks, 0);
    expect(local.requests, 0);
  });

  test(
    'a session change during the explanation prevents the OS request',
    () async {
      final local = TestLocalNotifications();

      addTearDown(local.close);

      var current = true;

      final outcome =
          await NotificationPermission(
            enabled: true,
            notifications: local,
            preferences: TestNotificationPreferences(),
          ).afterPayment(
            explain: () async {
              current = false;
              return true;
            },
            isCurrent: () => current,
          );

      expect(outcome, PermissionOutcome.cancelled);
      expect(local.requests, 0);
    },
  );

  test('overlapping payment callbacks show one explanation', () async {
    final local = TestLocalNotifications();

    addTearDown(local.close);

    final explanation = Completer<bool>();
    final opened = Completer<void>();

    final permission = NotificationPermission(
      enabled: true,
      notifications: local,
      preferences: TestNotificationPreferences(),
    );

    final first = permission.afterPayment(
      explain: () {
        opened.complete();
        return explanation.future;
      },
      isCurrent: () => true,
    );

    await opened.future;

    final second = await permission.afterPayment(
      explain: () => throw StateError('Duplicate explanation'),
      isCurrent: () => true,
    );

    expect(second, PermissionOutcome.handled);

    explanation.complete(false);

    expect(await first, PermissionOutcome.notNow);
    expect(local.requests, 0);
  });

  test(
    'clearing a refresh token preserves notification and sign-out settings',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'refresh': 'private-token',
        'notification-choice': 'yes',
        'signed-out': 'yes',
      });

      const storage = FlutterSecureStorage();

      const store = SecureRefreshTokenStore(storage: storage, key: 'refresh');

      await store.clear();

      expect(await store.read(), isNull);
      expect(await storage.read(key: 'notification-choice'), 'yes');
      expect(await storage.read(key: 'signed-out'), 'yes');
    },
  );

  test('both Firebase and local cold-start taps use the same parser', () async {
    for (final fromLocal in [false, true]) {
      final messages = TestPushMessages(first: fromLocal ? null : pushData);

      final local = TestLocalNotifications()
        ..first = fromLocal ? PushTarget.parse(pushData)!.payload : null;

      final runtime = PushRuntime(messages: messages, notifications: local);

      try {
        await runtime.start();

        expect(
          runtime.initialTarget!.location,
          '/stokvels/$testStokvelId/cycles/$testCycleId',
        );
      } finally {
        await runtime.dispose();
        await messages.close();
        await local.close();
      }
    }
  });

  test(
    'foreground refresh does not depend on notification permission',
    () async {
      final messages = TestPushMessages();
      final local = TestLocalNotifications();

      final runtime = PushRuntime(messages: messages, notifications: local);

      final updates = <PushTarget>[];
      final taps = <PushTarget>[];

      final subscription = runtime.updates.listen(updates.add);
      final tapSubscription = runtime.taps.listen(taps.add);

      try {
        await runtime.start();

        runtime.synchronize(
          const AuthSignedIn(
            identity: testIdentity,
            accessToken: null,
            sessionId: 1,
          ),
        );

        messages.received.add(pushData);
        await pumpEventQueue();

        expect(updates, hasLength(1));
        expect(local.shown, isEmpty);

        local.permission = true;

        messages.received.add(pushData);
        await pumpEventQueue();

        expect(updates, hasLength(2));
        expect(local.shown, hasLength(1));
        expect(taps, isEmpty);

        messages.tapped.add({...pushData, 'cycleId': '/profile'});

        expect(taps, isEmpty);

        messages.tapped.add(pushData);

        expect(
          taps.single.location,
          '/stokvels/$testStokvelId/cycles/$testCycleId',
        );

        runtime.synchronize(const AuthSignedOut());

        await pumpEventQueue();

        messages.received.add(pushData);

        await pumpEventQueue();

        expect(updates, hasLength(2));
        expect(local.clears, 1);
        expect(runtime.takePending(), isNull);
      } finally {
        await subscription.cancel();
        await tapSubscription.cancel();
        await runtime.dispose();
        await messages.close();
        await local.close();
      }
    },
  );
}
