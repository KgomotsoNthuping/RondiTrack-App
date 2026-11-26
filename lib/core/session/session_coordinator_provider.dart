import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/offline/data/offline_database_provider.dart';
import 'package:ronditrack/core/offline/offline_enabled.dart';
import 'package:ronditrack/core/push/device_providers.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/data/auth_api_provider.dart';
import 'package:ronditrack/core/session/data/drift_session_persistence.dart';
import 'package:ronditrack/core/session/data/platform_sign_out_marker.dart';
import 'package:ronditrack/core/session/data/secure_refresh_token_store.dart';
import 'package:ronditrack/core/session/session_coordinator.dart';

part 'session_coordinator_provider.g.dart';

@Riverpod(keepAlive: true)
Raw<SessionCoordinator> sessionCoordinator(Ref ref) {
  final api = ref.watch(authApiProvider);
  final config = ref.watch(appConfigProvider);
  final origin = Uri.encodeComponent(config.apiBaseUrl.toString());

  final coordinator = SessionCoordinator(
    api: api,
    devices: ref.watch(sessionDevicesProvider),
    refreshTokenStore: api.browserManagedCookies
        ? null
        : ref.watch(refreshTokenStoreProvider),
    signOutMarker: createSignOutMarker(
      'ronditrack.signed-out.${config.flavor.name}.$origin',
    ),
    persistence: ref.watch(offlineEnabledProvider)
        ? DriftSessionPersistence(ref.watch(offlineDatabaseProvider))
        : null,
  );

  ref.onDispose(coordinator.dispose);
  unawaited(coordinator.restore());

  return coordinator;
}

@Riverpod(keepAlive: true)
class SessionState extends _$SessionState {
  @override
  AuthState build() {
    final coordinator = ref.watch(sessionCoordinatorProvider);

    void update() {
      state = coordinator.state;
    }

    coordinator.addListener(update);

    ref.onDispose(() {
      coordinator.removeListener(update);
    });

    return coordinator.state;
  }
}
