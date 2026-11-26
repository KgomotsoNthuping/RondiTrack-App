import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/push/data/secure_notification_preferences.dart';
import 'package:ronditrack/core/push/notification_permission.dart';
import 'package:ronditrack/core/push/notification_ports.dart';
import 'package:ronditrack/core/push/push_runtime.dart';

final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(),
);

final pushRuntimeProvider = Provider<PushRuntime>((ref) {
  final runtime = PushRuntime.disabled();

  ref.onDispose(() => unawaited(runtime.dispose()));

  return runtime;
});

final notificationPreferencesProvider = Provider<NotificationPreferences>((
  ref,
) {
  final flavor = ref.watch(appConfigProvider).flavor.name;

  return SecureNotificationPreferences(
    storage: const FlutterSecureStorage(),
    key: 'ronditrack.notifications.$flavor.explained.v1',
  );
});

final notificationPermissionProvider = Provider<NotificationPermission>((ref) {
  final runtime = ref.watch(pushRuntimeProvider);

  return NotificationPermission(
    enabled: runtime.enabled,
    notifications: runtime.notifications,
    preferences: ref.watch(notificationPreferencesProvider),
  );
});

final paymentRecordedProvider = NotifierProvider<PaymentRecorded, int>(
  PaymentRecorded.new,
);

final class PaymentRecorded extends Notifier<int> {
  @override
  int build() => 0;

  void record() => state++;
}

typedef PushRevisionKey = ({
  String userId,
  int sessionId,
  String stokvelId,
  String cycleId,
});

final pushRevisionsProvider =
    NotifierProvider<PushRevisions, Map<PushRevisionKey, int>>(
      PushRevisions.new,
    );

final class PushRevisions extends Notifier<Map<PushRevisionKey, int>> {
  @override
  Map<PushRevisionKey, int> build() => const {};

  void changed(PushRevisionKey key) {
    state = {...state, key: (state[key] ?? 0) + 1};
  }

  void clear() => state = const {};
}
