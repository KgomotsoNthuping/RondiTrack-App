import 'package:ronditrack/features/payouts/domain/payout_order.dart';

abstract interface class PayoutRepository {
  Future<PayoutOrder> fetchOrder(String userId, PayoutCycleKey cycle);
}

final class PayoutOrderNotFound implements Exception {
  const new();

  @override
  String toString() => 'Not found';
}
