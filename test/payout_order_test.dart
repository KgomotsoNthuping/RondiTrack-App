import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/payouts/data/fake_payout_repository.dart';
import 'package:ronditrack/features/payouts/domain/payout_order.dart';
import 'package:ronditrack/features/payouts/domain/payout_repository.dart';
import 'package:ronditrack/features/stokvels/data/fake_stokvel_repository.dart';

const _family = (stokvelId: 'family-savers', cycleId: 'family-cycle-1');
const _work = (stokvelId: 'work-savers', cycleId: 'work-cycle-1');

const _repository = FakePayoutRepository(
  stokvelRepository: FakeStokvelRepository(delay: Duration.zero),
);

void main() {
  test('maps known payout statuses and labels unfamiliar values', () {
    for (final (value, status, label) in const [
      ('Waiting', PayoutStatus.waiting, 'Waiting'),
      ('Next', PayoutStatus.next, 'Next to be paid'),
      ('Paid', PayoutStatus.paid, 'Paid'),
      ('Reversed', PayoutStatus.unknown, 'Unknown payout status'),
    ]) {
      expect(PayoutStatus.fromApi(value), status);
      expect(status.label, label);
    }
  });

  test('members receive the seeded order and next recipient', () async {
    final order = await _repository.fetchOrder('lerato', _family);

    expect(order, await _repository.fetchOrder('nandi', _family));
    expect(order.stokvelId, _family.stokvelId);
    expect(order.cycleId, _family.cycleId);
    expect(order.entries.map((entry) => entry.userId), [
      'nandi',
      'lerato',
      'thabo',
    ]);
    expect(order.entries.map((entry) => entry.position), [1, 2, 3]);
    expect(order.entries.map((entry) => entry.status), [
      PayoutStatus.waiting,
      PayoutStatus.next,
      PayoutStatus.waiting,
    ]);
    expect(order.entries[1].amount, const Cents(150_000));
  });

  test('a member can read a cycle with an empty order', () async {
    final order = await _repository.fetchOrder('lerato', _work);

    expect(order.cycleId, _work.cycleId);
    expect(order.entries, isEmpty);
  });

  test('non-members, missing stokvels and mismatched cycles get not found',
      () async {
    for (final (userId, cycle) in const [
      ('naledi', _family),
      ('nandi', _work),
      ('lerato', (stokvelId: 'missing', cycleId: 'missing')),
      ('lerato', (stokvelId: 'family-savers', cycleId: 'work-cycle-1')),
    ]) {
      await expectLater(
        _repository.fetchOrder(userId, cycle),
        throwsA(isA<PayoutOrderNotFound>()),
      );
    }
  });

  test('Naledi can read the updated order after joining Family Savers', () async {
    const repository = FakePayoutRepository(
      stokvelRepository: FakeStokvelRepository(
        delay: Duration.zero,
        nalediJoinedFamily: true,
      ),
      nalediJoinedFamily: true,
    );

    final order = await repository.fetchOrder('naledi', _family);

    expect(order.entries.last.userId, 'naledi');
    expect(order.entries.last.amount, const Cents(200_000));
    expect(order.entries.last.status, PayoutStatus.waiting);
  });
}