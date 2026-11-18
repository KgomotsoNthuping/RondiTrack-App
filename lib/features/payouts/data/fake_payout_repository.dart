import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/payouts/domain/payout_order.dart';
import 'package:ronditrack/features/payouts/domain/payout_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_repository.dart';

final class FakePayoutRepository implements PayoutRepository {
  const new({
    required StokvelRepository stokvelRepository,
    this.nalediJoinedFamily = false,
  }) : _stokvelRepository = stokvelRepository;

  final StokvelRepository _stokvelRepository;
  final bool nalediJoinedFamily;

  static final PayoutOrder _family = _familyOrder(includeNaledi: false);
  static final PayoutOrder _familyAfterInvite = _familyOrder(
    includeNaledi: true,
  );

  static const _work = PayoutOrder(
    stokvelId: 'work-savers',
    cycleId: 'work-cycle-1',
    entries: [],
  );

  @override
  Future<PayoutOrder> fetchOrder(String userId, PayoutCycleKey cycle) async {
    final stokvel = await _stokvelRepository.fetchDetail(
      userId,
      cycle.stokvelId,
    );

    if (stokvel?.currentCycle?.id != cycle.cycleId) {
      throw const PayoutOrderNotFound();
    }

    return switch (cycle) {
      (stokvelId: 'family-savers', cycleId: 'family-cycle-1') =>
        nalediJoinedFamily ? _familyAfterInvite : _family,
      (stokvelId: 'work-savers', cycleId: 'work-cycle-1') => _work,
      _ => throw const PayoutOrderNotFound(),
    };
  }

  static PayoutOrder _familyOrder({required bool includeNaledi}) {
    final amount = includeNaledi ? const Cents(200_000) : const Cents(150_000);

    return PayoutOrder(
      stokvelId: 'family-savers',
      cycleId: 'family-cycle-1',
      entries: [
        PayoutOrderEntry(
          userId: 'nandi',
          memberName: 'Nandi',
          position: 1,
          amount: amount,
          status: PayoutStatus.waiting,
        ),
        PayoutOrderEntry(
          userId: 'lerato',
          memberName: 'Lerato',
          position: 2,
          amount: amount,
          status: PayoutStatus.next,
        ),
        PayoutOrderEntry(
          userId: 'thabo',
          memberName: 'Thabo',
          position: 3,
          amount: amount,
          status: PayoutStatus.waiting,
        ),
        if (includeNaledi)
          PayoutOrderEntry(
            userId: 'naledi',
            memberName: 'Naledi',
            position: 4,
            amount: amount,
            status: PayoutStatus.waiting,
          ),
      ],
    );
  }
}
