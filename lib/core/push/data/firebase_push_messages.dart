import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:ronditrack/core/push/notification_ports.dart';

final class FirebasePushMessages implements PushMessages {
  const FirebasePushMessages(this.messaging);

  final FirebaseMessaging messaging;

  @override
  bool get enabled => true;

  @override
  Stream<Map<String, Object?>> get foreground => FirebaseMessaging.onMessage
      .map((message) => Map<String, Object?>.from(message.data));

  @override
  Stream<Map<String, Object?>> get opened => FirebaseMessaging
      .onMessageOpenedApp
      .map((message) => Map<String, Object?>.from(message.data));

  @override
  Future<Map<String, Object?>?> initial() async {
    final message = await messaging.getInitialMessage();

    return message == null ? null : Map<String, Object?>.from(message.data);
  }
}
