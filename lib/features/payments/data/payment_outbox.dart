import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/core/offline/data/cache_json.dart';
import 'package:ronditrack/features/payments/domain/pending_payment.dart';

@DataClassName('QueuedPaymentRow')
class PaymentOutboxRows extends Table {
  TextColumn get idempotencyKey => text()();

  TextColumn get userId => text()();

  TextColumn get stokvelId => text()();

  TextColumn get cycleId => text()();

  IntColumn get amountInCents => integer()();

  TextColumn get frozenBody => text()();

  IntColumn get createdAtUtcMs => integer()();

  TextColumn get phase => text().withDefault(const Constant('pending'))();

  IntColumn get retryAtUtcMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {idempotencyKey};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, stokvelId, cycleId},
  ];
}

@DataClassName('StoredPaymentNoticeRow')
class PaymentNoticeRows extends Table {
  TextColumn get idempotencyKey => text()();

  TextColumn get userId => text()();

  TextColumn get payload => text()();

  IntColumn get createdAtUtcMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {idempotencyKey};
}

final class PaymentOutbox {
  new(this._database, {String Function()? newKey})
    : _newKey = newKey ?? createPaymentKey;

  final AppDatabase _database;
  final String Function() _newKey;

  int get generation => _database.generation;

  Stream<List<PendingPayment>> watch(String userId) {
    final query = _database.select(_database.paymentOutboxRows)
      ..where((row) => row.userId.equals(userId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.createdAtUtcMs),
        (row) => OrderingTerm.asc(row.idempotencyKey),
      ]);

    return query.watch().map(
      (rows) => rows.map(_readPayment).toList(growable: false),
    );
  }

  Future<List<PendingPayment>> read(String userId) {
    return watch(userId).first;
  }

  Stream<List<PaymentNotice>> watchNotices(String userId) {
    final query = _database.select(_database.paymentNoticeRows)
      ..where((row) => row.userId.equals(userId))
      ..orderBy([(row) => OrderingTerm.desc(row.createdAtUtcMs)]);

    return query.watch().map(
      (rows) => rows.map(_readNotice).toList(growable: false),
    );
  }

  Future<bool> hasPendingPayments() async {
    final rows = await (_database.select(
      _database.paymentOutboxRows,
    )..limit(1)).get();

    return rows.isNotEmpty;
  }

  Future<PendingPayment> enqueue({
    required int generation,
    required String userId,
    required String stokvelId,
    required String cycleId,
    required Cents amount,
    required DateTime createdAtUtc,
  }) async {
    if (amount.value <= 0 || amount.value > 9_007_199_254_740_991) {
      throw ArgumentError.value(amount.value, 'amount');
    }

    PendingPayment? result;

    final accepted = await _database.writeIfCurrent(generation, () async {
      final existing = await _findIntent(userId, stokvelId, cycleId);

      if (existing != null) {
        result = _readPayment(existing);
        return;
      }

      final key = _newKey();

      final body = jsonEncode({
        'userId': userId,
        'amountInCents': amount.value,
      });

      await _database
          .into(_database.paymentOutboxRows)
          .insert(
            PaymentOutboxRowsCompanion.insert(
              idempotencyKey: key,
              userId: userId,
              stokvelId: stokvelId,
              cycleId: cycleId,
              amountInCents: amount.value,
              frozenBody: body,
              createdAtUtcMs: createdAtUtc.toUtc().millisecondsSinceEpoch,
            ),
            mode: InsertMode.insertOrIgnore,
          );

      final stored = await _findIntent(userId, stokvelId, cycleId);

      if (stored == null) {
        throw StateError('The payment could not be saved.');
      }

      result = _readPayment(stored);
    });

    if (!accepted || result == null) {
      throw const RuleFailure(
        detail: 'The account changed before the payment was saved.',
      );
    }

    return result!;
  }

  Future<bool> hold({
    required int generation,
    required PendingPayment payment,
    required PaymentPhase phase,
    DateTime? retryAtUtc,
  }) {
    return _database.writeIfCurrent(generation, () async {
      await (_database.update(_database.paymentOutboxRows)..where(
            (row) =>
                row.idempotencyKey.equals(payment.key) &
                row.userId.equals(payment.userId),
          ))
          .write(
            PaymentOutboxRowsCompanion(
              phase: Value(phase.name),
              retryAtUtcMs: Value(retryAtUtc?.toUtc().millisecondsSinceEpoch),
            ),
          );

      await (_database.delete(_database.paymentNoticeRows)..where(
            (row) =>
                row.idempotencyKey.equals(payment.key) &
                row.userId.equals(payment.userId),
          ))
          .go();
    });
  }

  Future<bool> requireReview({
    required int generation,
    required PendingPayment payment,
    required PaymentPhase phase,
    required PaymentNoticeKind kind,
    required DateTime nowUtc,
  }) {
    return _database.writeIfCurrent(generation, () async {
      await (_database.update(_database.paymentOutboxRows)..where(
            (row) =>
                row.idempotencyKey.equals(payment.key) &
                row.userId.equals(payment.userId),
          ))
          .write(
            PaymentOutboxRowsCompanion(
              phase: Value(phase.name),
              retryAtUtcMs: const Value(null),
            ),
          );

      await _writeNotice(payment: payment, kind: kind, nowUtc: nowUtc);
    });
  }

  Future<bool> finish({
    required int generation,
    required PendingPayment payment,
    required PaymentNoticeKind kind,
    required DateTime nowUtc,
    Failure? failure,
    String? contributionId,
  }) {
    return _database.writeIfCurrent(generation, () async {
      await _writeNotice(
        payment: payment,
        kind: kind,
        nowUtc: nowUtc,
        failure: failure,
        contributionId: contributionId,
      );

      await (_database.delete(_database.paymentOutboxRows)..where(
            (row) =>
                row.idempotencyKey.equals(payment.key) &
                row.userId.equals(payment.userId),
          ))
          .go();
    });
  }

  Future<bool> acknowledgeExpired({
    required int generation,
    required String userId,
    required String key,
  }) {
    return _database.writeIfCurrent(generation, () async {
      final row =
          await (_database.select(_database.paymentOutboxRows)..where(
                (row) =>
                    row.idempotencyKey.equals(key) & row.userId.equals(userId),
              ))
              .getSingleOrNull();

      if (row == null || row.phase != PaymentPhase.expired.name) {
        return;
      }

      await (_database.delete(_database.paymentOutboxRows)..where(
            (row) => row.idempotencyKey.equals(key) & row.userId.equals(userId),
          ))
          .go();

      await (_database.delete(_database.paymentNoticeRows)..where(
            (row) => row.idempotencyKey.equals(key) & row.userId.equals(userId),
          ))
          .go();
    });
  }

  Future<QueuedPaymentRow?> _findIntent(
    String userId,
    String stokvelId,
    String cycleId,
  ) {
    return (_database.select(_database.paymentOutboxRows)..where(
          (row) =>
              row.userId.equals(userId) &
              row.stokvelId.equals(stokvelId) &
              row.cycleId.equals(cycleId),
        ))
        .getSingleOrNull();
  }

  Future<void> _writeNotice({
    required PendingPayment payment,
    required PaymentNoticeKind kind,
    required DateTime nowUtc,
    Failure? failure,
    String? contributionId,
  }) async {
    final errors = failure is ValidationFailure
        ? failure.errors
        : const <String, List<String>>{};

    await _database
        .into(_database.paymentNoticeRows)
        .insertOnConflictUpdate(
          PaymentNoticeRowsCompanion.insert(
            idempotencyKey: payment.key,
            userId: payment.userId,
            createdAtUtcMs: nowUtc.toUtc().millisecondsSinceEpoch,
            payload: jsonEncode({
              'stokvelId': payment.stokvelId,
              'cycleId': payment.cycleId,
              'amountInCents': payment.amount.value,
              'kind': kind.name,
              'detail': failure?.message,
              'contributionId': contributionId,
              'errors': errors,
            }),
          ),
        );
  }
}

PendingPayment _readPayment(QueuedPaymentRow row) {
  return PendingPayment(
    key: row.idempotencyKey,
    userId: row.userId,
    stokvelId: row.stokvelId,
    cycleId: row.cycleId,
    amount: Cents(row.amountInCents),
    frozenBody: row.frozenBody,
    createdAtUtc: cacheTimestamp(row.createdAtUtcMs),
    phase: PaymentPhase.values.byName(row.phase),
    retryAtUtc: row.retryAtUtcMs == null
        ? null
        : cacheTimestamp(row.retryAtUtcMs!),
  );
}

PaymentNotice _readNotice(StoredPaymentNoticeRow row) {
  final json = cacheObject(jsonDecode(row.payload));
  final rawErrors = cacheObject(json['errors']);

  return PaymentNotice(
    key: row.idempotencyKey,
    userId: row.userId,
    stokvelId: json['stokvelId']! as String,
    cycleId: json['cycleId']! as String,
    amount: Cents(json['amountInCents']! as int),
    kind: PaymentNoticeKind.values.byName(json['kind']! as String),
    createdAtUtc: cacheTimestamp(row.createdAtUtcMs),
    detail: json['detail'] as String?,
    contributionId: json['contributionId'] as String?,
    errors: {
      for (final entry in rawErrors.entries)
        entry.key: cacheList(entry.value).cast<String>(),
    },
  );
}

String createPaymentKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));

  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
