import 'package:ronditrack/core/push/push_target.dart';

abstract interface class PushMessages {
  bool get enabled;

  Stream<Map<String, Object?>> get foreground;

  Stream<Map<String, Object?>> get opened;

  Future<Map<String, Object?>?> initial();
}

abstract interface class LocalNotifications {
  bool get enabled;

  Stream<String> get opened;

  Future<void> initialize();

  Future<String?> initialPayload();

  Future<bool> allowed();

  Future<bool> requestPermission();

  Future<void> show(PushTarget target);

  Future<void> clear();

  Future<void> openSettings();
}

abstract interface class NotificationPreferences {
  Future<bool> handled();

  Future<void> markHandled();
}

final class NoopPushMessages implements PushMessages {
  const NoopPushMessages();

  @override
  bool get enabled => false;

  @override
  Stream<Map<String, Object?>> get foreground => const Stream.empty();

  @override
  Stream<Map<String, Object?>> get opened => const Stream.empty();

  @override
  Future<Map<String, Object?>?> initial() async => null;
}

final class NoopLocalNotifications implements LocalNotifications {
  const NoopLocalNotifications();

  @override
  bool get enabled => false;

  @override
  Stream<String> get opened => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> initialPayload() async => null;

  @override
  Future<bool> allowed() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show(PushTarget target) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> openSettings() async {}
}
