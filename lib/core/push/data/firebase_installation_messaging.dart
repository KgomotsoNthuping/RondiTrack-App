import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:ronditrack/core/config/firebase_settings.dart';
import 'package:ronditrack/core/push/installation_messaging.dart';

typedef MessagingInitializer = Future<InstallationMessaging> Function(
  FirebaseSettings settings,
);

Future<InstallationMessaging> createInstallationMessaging(
  FirebaseSettings settings, {
  required bool isTest,
  bool? isAndroid,
  MessagingInitializer initialize = _initialize,
}) async {
  final supported =
      isAndroid ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  if (isTest || !settings.enabled || !supported) {
    return const NoopInstallationMessaging();
  }

  try {
    return await initialize(settings).timeout(const Duration(seconds: 5));
  } on Object {
    return const NoopInstallationMessaging();
  }
}

Future<InstallationMessaging> _initialize(FirebaseSettings settings) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: settings.values['FIREBASE_API_KEY']!,
        appId: settings.values['FIREBASE_APP_ID']!,
        messagingSenderId: settings.values['FIREBASE_MESSAGING_SENDER_ID']!,
        projectId: settings.values['FIREBASE_PROJECT_ID']!,
      ),
    );
  }

  final messaging = FirebaseMessaging.instance;
  await messaging.setAutoInitEnabled(false);

  return FirebaseInstallationMessaging(messaging);
}

final class FirebaseInstallationMessaging implements InstallationMessaging {
  const new(this.messaging);

  final FirebaseMessaging messaging;

  @override
  bool get enabled => true;

  @override
  Stream<String> get onRegistered => messaging.onRegistered;

  @override
  Future<void> register() => messaging.register();

  @override
  Future<void> unregister() => messaging.unregister();
}
