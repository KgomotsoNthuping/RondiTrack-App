import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/data/cached_account_store.dart';
import 'package:ronditrack/core/session/session_persistence.dart';

final class DriftSessionPersistence implements SessionPersistence {
  DriftSessionPersistence(this._database);

  final AppDatabase _database;

  @override
  Future<AuthIdentity?> readIdentity() {
    return CachedAccountStore(_database).read();
  }

  @override
  Future<void> rememberIdentity(AuthIdentity identity) async {
    final accepted = await CachedAccountStore(_database).remember(
      generation: _database.generation,
      identity: identity,
    );

    if (!accepted) {
      throw StateError('The account changed before it could be saved.');
    }
  }

  @override
  void invalidateWrites() {
    _database.invalidateWrites();
  }

  @override
  Future<void> clear() {
    return _database.clearForSignOut();
  }
}