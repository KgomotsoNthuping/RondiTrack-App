import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ronditrack/core/push/notification_ports.dart';
import 'package:ronditrack/core/push/push_target.dart';

final class AndroidLocalNotifications implements LocalNotifications {
  static const channelId = 'ronditrack_updates';
  static const channelName = 'Stokvel updates';
  static const title = 'RondiTrack';
  static const body = "There's an update on your stokvel.";

  final _plugin = FlutterLocalNotificationsPlugin();
  final _opened = StreamController<String>.broadcast(sync: true);

  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  bool get enabled => _ready;

  @override
  Stream<String> get opened => _opened.stream;

  @override
  Future<void> initialize() async {
    await const MethodChannel('ronditrack/notifications')
        .invokeMethod<void>('ensureChannel');

    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_ronditrack'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;

        if (payload != null) {
          _opened.add(payload);
        }
      },
    );

    _ready = initialized == true;
  }

  @override
  Future<String?> initialPayload() async {
    if (!_ready) {
      return null;
    }

    final details = await _plugin.getNotificationAppLaunchDetails();

    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse?.payload
        : null;
  }

  @override
  Future<bool> allowed() async =>
      _ready && (await _android?.areNotificationsEnabled()) == true;

  @override
  Future<bool> requestPermission() async =>
      _ready && (await _android?.requestNotificationsPermission()) == true;

  @override
  Future<void> show(PushTarget target) async {
    if (!_ready) {
      return;
    }

    await _plugin.show(
      id: 1202,
      title: title,
      body: body,
      payload: target.payload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Updates from RondiTrack.',
          icon: 'ic_stat_ronditrack',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
        ),
      ),
    );
  }

  @override
  Future<void> clear() => _ready ? _plugin.cancelAll() : Future<void>.value();

  @override
  Future<void> openSettings() async {
    if (_ready) {
      await _android?.openAppNotificationSettings();
    }
  }
}
