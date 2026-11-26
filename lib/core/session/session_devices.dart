import 'package:ronditrack/core/session/auth_state.dart';

abstract interface class SessionDevices {
  bool get enabled;

  Future<void> synchronize(AuthState state);

  Future<void> beforeSignOut(AuthState state);
}

final class NoopSessionDevices implements SessionDevices {
  const new();

  @override
  bool get enabled => false;

  @override
  Future<void> synchronize(AuthState state) async {}

  @override
  Future<void> beforeSignOut(AuthState state) async {}
}
