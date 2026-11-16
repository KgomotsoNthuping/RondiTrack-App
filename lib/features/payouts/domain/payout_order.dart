import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ronditrack/core/money/cents.dart';

part 'payout_order.freezed.dart';

typedef PayoutCycleKey = ({String stokvelId, String cycleId});

enum PayoutStatus {
  waiting,
  next,
  paid,
  unknown;

  static PayoutStatus fromApi(String value) => switch (value) {
    'Waiting' => PayoutStatus.waiting,
    'Next' => PayoutStatus.next,
    'Paid' => PayoutStatus.paid,
    _ => PayoutStatus.unknown,
  };

  String get label => switch (this) {
    PayoutStatus.waiting => 'Waiting',
    PayoutStatus.next => 'Next to be paid',
    PayoutStatus.paid => 'Paid',
    PayoutStatus.unknown => 'Unknown payout status',
  };
}

@freezed
abstract class PayoutOrder with _$PayoutOrder {
  const factory({
    required String stokvelId,
    required String cycleId,
    required List<PayoutOrderEntry> entries,
  }) = _PayoutOrder;
}

@freezed
abstract class PayoutOrderEntry with _$PayoutOrderEntry {
  const factory({
    required String userId,
    required String memberName,
    required int position,
    required Cents amount,
    required PayoutStatus status,
    DateTime? paidAtUtc,
  }) = _PayoutOrderEntry;
}
