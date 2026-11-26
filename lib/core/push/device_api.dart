import 'package:ronditrack/core/session/access_token_store.dart';

abstract interface class DeviceApi {
  Future<bool> register(String installationId, AccessToken access);

  Future<bool> forget(String installationId, AccessToken access);

  void cancelPending();
}
