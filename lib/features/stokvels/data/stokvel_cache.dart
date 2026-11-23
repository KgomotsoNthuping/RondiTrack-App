import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/offline/cached_value.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/core/offline/data/cache_json.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

class StokvelCacheRows extends Table {
  TextColumn get ownerId => text()();

  TextColumn get stokvelId => text()();

  TextColumn get payload => text()();

  IntColumn get updatedAtUtcMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId, stokvelId};
}

class CurrentCycleCacheRows extends Table {
  TextColumn get ownerId => text()();

  TextColumn get stokvelId => text()();

  TextColumn get payload => text()();

  IntColumn get updatedAtUtcMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId, stokvelId};
}

final class StokvelCache {
  StokvelCache(this._db);

  final AppDatabase _db;

  Stream<CachedValue<Stokvel>?> watch(String userId, String stokvelId) {
    final details = _db.stokvelCacheRows;
    final cycles = _db.currentCycleCacheRows;

    final query =
        _db.select(details).join([
          leftOuterJoin(
            cycles,
            cycles.ownerId.equalsExp(details.ownerId) &
                cycles.stokvelId.equalsExp(details.stokvelId),
          ),
        ])..where(
          details.ownerId.equals(userId) & details.stokvelId.equals(stokvelId),
        );

    return query.watchSingleOrNull().map((row) {
      if (row == null) {
        return null;
      }

      final detail = row.readTable(details);
      final cycle = row.readTableOrNull(cycles);

      return CachedValue(
        value: _decodeStokvel(
          cacheObject(jsonDecode(detail.payload)),
          cycle == null
              ? null
              : _decodeCycle(cacheObject(jsonDecode(cycle.payload))),
        ),
        updatedAtUtc: cacheTimestamp(detail.updatedAtUtcMs),
      );
    });
  }

  Future<CachedValue<Stokvel>?> read(String userId, String stokvelId) {
    return watch(userId, stokvelId).first;
  }

  Future<bool> replace({
    required int generation,
    required String userId,
    required Stokvel value,
    required DateTime updatedAtUtc,
  }) {
    return _db.writeIfCurrent(generation, () async {
      final stokvelId = value.membership.stokvelId;

      await _db
          .into(_db.stokvelCacheRows)
          .insertOnConflictUpdate(
            StokvelCacheRowsCompanion.insert(
              ownerId: userId,
              stokvelId: stokvelId,
              payload: jsonEncode(_encodeStokvel(value)),
              updatedAtUtcMs: updatedAtUtc.toUtc().millisecondsSinceEpoch,
            ),
          );

      final cycle = value.currentCycle;

      if (cycle == null) {
        await (_db.delete(_db.currentCycleCacheRows)..where(
              (row) =>
                  row.ownerId.equals(userId) & row.stokvelId.equals(stokvelId),
            ))
            .go();
      } else {
        await CurrentCycleCache(_db)
            ._write(userId, stokvelId, cycle, updatedAtUtc);
      }
    });
  }

  Future<bool> remove({
    required int generation,
    required String userId,
    required String stokvelId,
  }) {
    return _db.writeIfCurrent(generation, () async {
      await (_db.delete(_db.currentCycleCacheRows)..where(
            (row) =>
                row.ownerId.equals(userId) & row.stokvelId.equals(stokvelId),
          ))
          .go();

      await (_db.delete(_db.stokvelCacheRows)..where(
            (row) =>
                row.ownerId.equals(userId) & row.stokvelId.equals(stokvelId),
          ))
          .go();
    });
  }
}

final class CurrentCycleCache {
  CurrentCycleCache(this._db);

  final AppDatabase _db;

  Stream<CachedValue<ContributionCycle>?> watch(
    String userId,
    String stokvelId,
  ) {
    final query = _db.select(_db.currentCycleCacheRows)
      ..where(
        (row) => row.ownerId.equals(userId) & row.stokvelId.equals(stokvelId),
      );

    return query.watchSingleOrNull().map((row) {
      if (row == null) {
        return null;
      }

      return CachedValue(
        value: _decodeCycle(cacheObject(jsonDecode(row.payload))),
        updatedAtUtc: cacheTimestamp(row.updatedAtUtcMs),
      );
    });
  }

  Future<CachedValue<ContributionCycle>?> read(
    String userId,
    String stokvelId,
  ) {
    return watch(userId, stokvelId).first;
  }

  Future<bool> replace({
    required int generation,
    required String userId,
    required String stokvelId,
    required ContributionCycle value,
    required DateTime updatedAtUtc,
  }) {
    return _db.writeIfCurrent(
      generation,
      () => _write(userId, stokvelId, value, updatedAtUtc),
    );
  }

  Future<void> _write(
    String userId,
    String stokvelId,
    ContributionCycle value,
    DateTime updatedAtUtc,
  ) async {
    await _db
        .into(_db.currentCycleCacheRows)
        .insertOnConflictUpdate(
          CurrentCycleCacheRowsCompanion.insert(
            ownerId: userId,
            stokvelId: stokvelId,
            payload: jsonEncode(_encodeCycle(value)),
            updatedAtUtcMs: updatedAtUtc.toUtc().millisecondsSinceEpoch,
          ),
        );
  }
}

Map<String, Object?> _encodeStokvel(Stokvel value) {
  return {
    'stokvelId': value.membership.stokvelId,
    'role': value.membership.role.name,
    'name': value.name,
    'monthlyContribution': value.monthlyContribution.value,
    'memberCount': value.memberCount,
    'currentPeriod': value.currentPeriod,
    'totalPeriods': value.totalPeriods,
    'rules': value.rules,
    'version': value.version,
    'contributions': [
      for (final contribution in value.contributions)
        {
          'id': contribution.id,
          'cycleId': contribution.cycleId,
          'cycleNumber': contribution.cycleNumber,
          'userId': contribution.userId,
          'memberName': contribution.memberName,
          'amount': contribution.amount.value,
          'status': contribution.status.name,
          'paidAtUtc': contribution.paidAtUtc?.toUtc().toIso8601String(),
        },
    ],
  };
}

Stokvel _decodeStokvel(Map<String, Object?> json, ContributionCycle? cycle) {
  return Stokvel(
    membership: Membership(
      stokvelId: json['stokvelId']! as String,
      role: StokvelRole.values.byName(json['role']! as String),
    ),
    name: json['name']! as String,
    monthlyContribution: Cents(json['monthlyContribution']! as int),
    memberCount: json['memberCount']! as int,
    currentPeriod: json['currentPeriod']! as int,
    totalPeriods: json['totalPeriods']! as int,
    rules: json['rules'] as String?,
    version: json['version'] as int?,
    currentCycle: cycle,
    contributions: [
      for (final item in cacheList(json['contributions']))
        _decodeContribution(cacheObject(item)),
    ],
  );
}

Contribution _decodeContribution(Map<String, Object?> json) {
  return Contribution(
    id: json['id']! as String,
    cycleId: json['cycleId']! as String,
    cycleNumber: json['cycleNumber']! as int,
    userId: json['userId']! as String,
    memberName: json['memberName']! as String,
    amount: Cents(json['amount']! as int),
    status: ContributionStatus.values.byName(json['status']! as String),
    paidAtUtc: cacheInstantFromJson(json['paidAtUtc']),
  );
}

Map<String, Object?> _encodeCycle(ContributionCycle value) {
  return {
    'id': value.id,
    'number': value.number,
    'status': value.status.name,
    'targetAmount': value.targetAmount.value,
    'totalCollected': value.totalCollected.value,
    'amountOutstanding': value.amountOutstanding.value,
    'dueDate': cacheDateToJson(value.dueDate),
    'version': value.version,
  };
}

ContributionCycle _decodeCycle(Map<String, Object?> json) {
  return ContributionCycle(
    id: json['id']! as String,
    number: json['number']! as int,
    status: CycleStatus.values.byName(json['status']! as String),
    targetAmount: Cents(json['targetAmount']! as int),
    totalCollected: Cents(json['totalCollected']! as int),
    amountOutstanding: Cents(json['amountOutstanding']! as int),
    dueDate: cacheDateFromJson(json['dueDate']),
    version: json['version'] as int?,
  );
}
