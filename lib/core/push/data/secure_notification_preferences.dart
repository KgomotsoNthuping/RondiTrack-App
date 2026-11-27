import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ronditrack/core/push/notification_ports.dart';

final class SecureNotificationPreferences implements NotificationPreferences {
  const new({required this.storage, required this.key});

  final FlutterSecureStorage storage;
  final String key;

  @override
  Future<bool> handled() async => await storage.read(key: key) == 'yes';

  @override
  Future<void> markHandled() => storage.write(key: key, value: 'yes');
}
