import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/offline/cached_value.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/core/offline/data/cache_json.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

class HomeCacheRows extends Table {
  TextColumn get ownerId => text()();

  TextColumn get payload => text()();

  IntColumn get updatedAtUtcMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId};
}

final class HomeCache {
  new(this._db);

  final AppDatabase _db;

  Stream<CachedValue<List<HomeEntry>>?> watch(String userId) {
    final query = _db.select(_db.homeCacheRows)
      ..where((row) => row.ownerId.equals(userId));

    return query.watchSingleOrNull().map((row) {
      if (row == null) {
        return null;
      }

      final entries = cacheList(jsonDecode(row.payload));

      return CachedValue(
        value: List<HomeEntry>.unmodifiable(entries.map(_decodeEntry)),
        updatedAtUtc: cacheTimestamp(row.updatedAtUtcMs),
      );
    });
  }

  Future<CachedValue<List<HomeEntry>>?> read(String userId) {
    return watch(userId).first;
  }

  Future<bool> replace({
    required int generation,
    required String userId,
    required List<HomeEntry> entries,
    required DateTime updatedAtUtc,
  }) {
    return _db.writeIfCurrent(generation, () async {
      await _db
          .into(_db.homeCacheRows)
          .insertOnConflictUpdate(
            HomeCacheRowsCompanion.insert(
              ownerId: userId,
              payload: jsonEncode(entries.map(_encodeEntry).toList()),
              updatedAtUtcMs: updatedAtUtc.toUtc().millisecondsSinceEpoch,
            ),
          );
    });
  }

  Future<bool> remove({required int generation, required String userId}) {
    return _db.writeIfCurrent(generation, () async {
      await (_db.delete(
        _db.homeCacheRows,
      )..where((row) => row.ownerId.equals(userId))).go();
    });
  }
}

Map<String, Object?> _encodeEntry(HomeEntry entry) {
  return {
    'stokvelId': entry.membership.stokvelId,
    'role': entry.membership.role.name,
    'name': entry.name,
    'arrears': entry.arrears.value,
    'currentCycleNumber': entry.currentCycleNumber,
    'cycleStatus': entry.cycleStatus?.name,
    'cycleDueDate': cacheDateToJson(entry.cycleDueDate),
    'paidThisCycle': entry.paidThisCycle?.value,
    'stillOwed': entry.stillOwed?.value,
    'nextPayoutDateUtc': entry.nextPayoutDateUtc?.toUtc().toIso8601String(),
  };
}

HomeEntry _decodeEntry(Object? value) {
  final json = cacheObject(value);
  final status = json['cycleStatus'] as String?;

  return HomeEntry(
    membership: Membership(
      stokvelId: json['stokvelId']! as String,
      role: StokvelRole.values.byName(json['role']! as String),
    ),
    name: json['name']! as String,
    arrears: Cents(json['arrears']! as int),
    currentCycleNumber: json['currentCycleNumber'] as int?,
    cycleStatus: status == null ? null : CycleStatus.values.byName(status),
    cycleDueDate: cacheDateFromJson(json['cycleDueDate']),
    paidThisCycle: cacheCentsFromJson(json['paidThisCycle']),
    stillOwed: cacheCentsFromJson(json['stillOwed']),
    nextPayoutDateUtc: cacheInstantFromJson(json['nextPayoutDateUtc']),
  );
}
