import 'package:ronditrack/core/session/auth_models.dart';

abstract interface class SessionPersistence {
  Future<AuthIdentity?> readIdentity();

  Future<void> rememberIdentity(AuthIdentity identity);

  void invalidateWrites();

  Future<void> clear();
}