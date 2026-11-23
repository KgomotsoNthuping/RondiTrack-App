import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:ronditrack/core/session/data/cached_account_store.dart';
import 'package:ronditrack/features/home/data/home_cache.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_cache.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    HomeCacheRows,
    StokvelCacheRows,
    CurrentCycleCacheRows,
    CachedAccountRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.persistent({required String name}) {
    return AppDatabase(
      driftDatabase(
        name: name,
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ),
    );
  }

  int _generation = 0;

  int get generation => _generation;

  @override
  int get schemaVersion => 1;

  Future<bool> writeIfCurrent(
    int expectedGeneration,
    Future<void> Function() operation,
  ) {
    return transaction(() async {
      if (expectedGeneration != _generation) {
        return false;
      }

      await operation();

      return expectedGeneration == _generation;
    });
  }

  Future<void> clearForSignOut() {
    _generation++;

    return transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}
