import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/network/data/api_dio_factory.dart';
import 'package:ronditrack/core/push/data/dio_device_api.dart';
import 'package:ronditrack/core/push/device_session.dart';
import 'package:ronditrack/core/push/installation_messaging.dart';
import 'package:ronditrack/core/session/session_devices.dart';

final installationMessagingProvider = Provider<InstallationMessaging>(
  (ref) => const NoopInstallationMessaging(),
);

final sessionDevicesProvider = Provider<SessionDevices>((ref) {
  final messaging = ref.watch(installationMessagingProvider);

  if (!messaging.enabled) {
    return const NoopSessionDevices();
  }

  final dio = createApiDio(ref.watch(appConfigProvider), writeLog: (_) {})
    ..options.followRedirects = false;

  final api = DioDeviceApi(dio);

  final devices = DeviceSession(messaging: messaging, api: api);

  ref.onDispose(() {
    devices.dispose();
    dio.close(force: true);
  });

  return devices;
});
