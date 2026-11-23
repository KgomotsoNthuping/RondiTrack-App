import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:ronditrack/core/session/data/cached_account_store.dart';
import 'package:ronditrack/features/home/data/home_cache.dart';
import 'package:ronditrack/features/payments/data/payment_outbox.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_cache.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    HomeCacheRows,
    StokvelCacheRows,
    CurrentCycleCacheRows,
    CachedAccountRows,
    PaymentOutboxRows,
    PaymentNoticeRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  new(super.executor);

  factory persistent({required String name}) {
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(paymentOutboxRows);
        await migrator.createTable(paymentNoticeRows);
      }
    },
  );

  void invalidateWrites() {
    _generation++;
  }

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
    invalidateWrites();

    return transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}
