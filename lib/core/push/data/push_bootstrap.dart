import 'package:ronditrack/core/push/data/android_local_notifications.dart';
import 'package:ronditrack/core/push/data/firebase_installation_messaging.dart';
import 'package:ronditrack/core/push/data/firebase_push_messages.dart';
import 'package:ronditrack/core/push/installation_messaging.dart';
import 'package:ronditrack/core/push/push_runtime.dart';

Future<PushRuntime> createPushRuntime(InstallationMessaging messaging) async {
  if (messaging is! FirebaseInstallationMessaging) {
    return PushRuntime.disabled();
  }

  final runtime = PushRuntime(
    messages: FirebasePushMessages(messaging.messaging),
    notifications: AndroidLocalNotifications(),
  );

  try {
    await runtime.start();
    return runtime;
  } on Object {
    await runtime.dispose();
    return PushRuntime.disabled();
  }
}
