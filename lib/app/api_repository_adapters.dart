import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/domain/home_repository.dart';
import 'package:ronditrack/features/payouts/domain/payout_order.dart';
import 'package:ronditrack/features/payouts/domain/payout_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_repository.dart';

typedef LoadHome = Future<Result<List<HomeEntry>>> Function(String userId);

typedef LoadStokvel = Future<Result<Stokvel>> Function(
  String userId,
  String stokvelId, {
  String? cycleId,
});

typedef LoadPayout = Future<Result<PayoutOrder>> Function(
  String userId,
  PayoutCycleKey cycle,
);

final class HomeResultAdapter implements HomeRepository {
  const new(this.load);

  final LoadHome load;

  @override
  Future<List<HomeEntry>> fetchHome(String userId) async {
    return _unwrap(await load(userId));
  }
}

final class StokvelResultAdapter
    implements StokvelRepository, StokvelCycleRepository {
  const new(this.load, {this.subject});

  final LoadStokvel load;
  final String? subject;

  @override
  Future<Stokvel?> fetchDetail(String userId, String stokvelId) async {
    return _unwrap(await load(subject ?? userId, stokvelId));
  }

  @override
  Future<Stokvel?> fetchCycleDetail(
    String userId,
    String stokvelId,
    String cycleId,
  ) async {
    return _unwrap(await load(subject ?? userId, stokvelId, cycleId: cycleId));
  }
}

final class PayoutResultAdapter implements PayoutRepository {
  const new(this.load);

  final LoadPayout load;

  @override
  Future<PayoutOrder> fetchOrder(String userId, PayoutCycleKey cycle) async {
    return _unwrap(await load(userId, cycle));
  }
}

T _unwrap<T>(Result<T> result) {
  return switch (result) {
    Ok<T>(:final value) => value,
    Err<T>(:final failure) => throw failure,
  };
}
