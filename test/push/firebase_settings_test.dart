import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/config/firebase_settings.dart';
import 'package:ronditrack/core/push/data/firebase_installation_messaging.dart';
import 'package:ronditrack/core/push/installation_messaging.dart';

void main() {
  FirebaseSettings configured() => FirebaseSettings.parse({
    for (final key in FirebaseSettings.keys) key: 'configured',
  });

  test('missing or empty values disable push', () {
    expect(FirebaseSettings.parse({}).enabled, isFalse);

    expect(
      FirebaseSettings.parse({
        for (final key in FirebaseSettings.keys) key: '  ',
      }).enabled,
      isFalse,
    );
  });

  test('all four settings enable configuration and remain immutable', () {
    final settings = configured();

    expect(settings.enabled, isTrue);
    expect(settings.values.keys, unorderedEquals(FirebaseSettings.keys));

    expect(
      () => settings.values['FIREBASE_API_KEY'] = 'changed',
      throwsUnsupportedError,
    );
  });

  test('partial configuration names missing keys without revealing values', () {
    try {
      FirebaseSettings.parse({'FIREBASE_API_KEY': 'private-example-value'});

      fail('Partial settings must be refused.');
    } on FormatException catch (error) {
      expect(error.message, contains('FIREBASE_APP_ID'));
      expect(error.message, contains('FIREBASE_MESSAGING_SENDER_ID'));
      expect(error.message, contains('FIREBASE_PROJECT_ID'));
      expect(error.message, isNot(contains('private-example-value')));
    }
  });

  for (final scenario in ['tests', 'disabled', 'unsupported']) {
    test('$scenario never initialises the Firebase SDK', () async {
      var calls = 0;

      final messaging = await createInstallationMessaging(
        scenario == 'disabled' ? FirebaseSettings.parse({}) : configured(),
        isTest: scenario == 'tests',
        isAndroid: scenario != 'unsupported',
        initialize: (_) async {
          calls++;
          return const NoopInstallationMessaging();
        },
      );

      expect(calls, 0);
      expect(messaging.enabled, isFalse);
    });
  }

  test('an SDK failure disables optional push without escaping', () async {
    var calls = 0;

    final messaging = await createInstallationMessaging(
      configured(),
      isTest: false,
      isAndroid: true,
      initialize: (_) async {
        calls++;
        throw StateError('Synthetic SDK failure.');
      },
    );

    expect(calls, 1);
    expect(messaging.enabled, isFalse);
  });
}
