import 'dart:async';

import 'package:ronditrack/core/push/notification_ports.dart';
import 'package:ronditrack/core/push/push_target.dart';

const pushData = <String, Object?>{
  'type': 'cycle_updated',
  'stokvelId': '22222222-2222-4222-8222-222222222222',
  'cycleId': '33333333-3333-4333-8333-333333333333',
};

final class TestPushMessages implements PushMessages {
  TestPushMessages({this.first});

  final Map<String, Object?>? first;

  final received = StreamController<Map<String, Object?>>.broadcast(sync: true);

  final tapped = StreamController<Map<String, Object?>>.broadcast(sync: true);

  @override
  bool get enabled => true;

  @override
  Stream<Map<String, Object?>> get foreground => received.stream;

  @override
  Stream<Map<String, Object?>> get opened => tapped.stream;

  @override
  Future<Map<String, Object?>?> initial() async => first;

  Future<void> close() async {
    await received.close();
    await tapped.close();
  }
}

final class TestLocalNotifications implements LocalNotifications {
  bool active = true;
  bool permission = false;
  bool requestResult = false;

  int requests = 0;
  int clears = 0;
  int checks = 0;

  String? first;

  final events = <String>[];
  final shown = <PushTarget>[];
  final tapped = StreamController<String>.broadcast(sync: true);

  @override
  bool get enabled => active;

  @override
  Stream<String> get opened => tapped.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> initialPayload() async => first;

  @override
  Future<bool> allowed() async {
    checks++;
    return permission;
  }

  @override
  Future<bool> requestPermission() async {
    requests++;
    events.add('request');
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<void> show(PushTarget target) async => shown.add(target);

  @override
  Future<void> clear() async {
    clears++;
    shown.clear();
  }

  @override
  Future<void> openSettings() async {}

  Future<void> close() => tapped.close();
}

final class TestNotificationPreferences implements NotificationPreferences {
  bool value = false;

  int reads = 0;
  int writes = 0;

  @override
  Future<bool> handled() async {
    reads++;
    return value;
  }

  @override
  Future<void> markHandled() async {
    writes++;
    value = true;
  }
}
