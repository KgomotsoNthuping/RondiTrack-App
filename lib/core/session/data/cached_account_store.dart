import 'package:drift/drift.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/core/session/auth_models.dart';

class CachedAccountRows extends Table {
  IntColumn get slot => integer()();

  TextColumn get userId => text()();

  TextColumn get email => text()();

  TextColumn get platformRole => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {slot};
}

final class CachedAccountStore {
  CachedAccountStore(this._db);

  final AppDatabase _db;

  Future<AuthIdentity?> read() async {
    final row = await (_db.select(
      _db.cachedAccountRows,
    )..where((row) => row.slot.equals(1))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    return AuthIdentity(
      userId: row.userId,
      email: row.email,
      platformRole: row.platformRole,
    );
  }

  Future<bool> remember({
    required int generation,
    required AuthIdentity identity,
  }) {
    return _db.writeIfCurrent(generation, () async {
      final previous = await read();

      if (previous != null && previous.userId != identity.userId) {
        throw StateError('Clear the previous account before replacing it.');
      }

      await _db
          .into(_db.cachedAccountRows)
          .insertOnConflictUpdate(
            CachedAccountRowsCompanion.insert(
              slot: 1,
              userId: identity.userId,
              email: identity.email,
              platformRole: Value(identity.platformRole),
            ),
          );
    });
  }
}
