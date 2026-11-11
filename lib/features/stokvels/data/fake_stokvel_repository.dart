import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

/// Serves the detail fixtures for the demo memberships.
final class FakeStokvelRepository implements StokvelRepository {
  /// Creates the fixture repository with configurable delays.
  const new({
    this.delay = const Duration(milliseconds: 350),
    this.workDelay,
    this.failRequests = false,
  });

  /// The default fixture response delay.
  final Duration delay;

  /// An optional longer delay for Work Savers.
  final Duration? workDelay;

  /// Simulates a failed request for a valid membership.
  final bool failRequests;

  static const _familyCycleId = 'family-cycle-1';
  static const _workCycleId = 'work-cycle-1';

  static final _family = Stokvel(
    membership: const Membership(
      stokvelId: 'family-savers',
      role: StokvelRole.treasurer,
    ),
    name: 'Family Savers',
    monthlyContribution: const Cents(50_000),
    memberCount: 3,
    currentPeriod: 1,
    totalPeriods: 12,
    currentCycle: const ContributionCycle(
      id: _familyCycleId,
      number: 1,
      status: CycleStatus.open,
      targetAmount: Cents(150_000),
      totalCollected: Cents(50_010),
      amountOutstanding: Cents(99_990),
      dueDate: (year: 2026, month: 10, day: 31),
    ),
    contributions: [
      Contribution(
        id: 'family-lerato',
        cycleId: _familyCycleId,
        cycleNumber: 1,
        userId: 'lerato',
        memberName: 'Lerato',
        amount: const Cents(50_000),
        status: ContributionStatus.confirmed,
        paidAtUtc: DateTime.utc(2026, 10, 15, 12),
      ),
      Contribution(
        id: 'family-nandi',
        cycleId: _familyCycleId,
        cycleNumber: 1,
        userId: 'nandi',
        memberName: 'Nandi',
        amount: const Cents(10),
        status: ContributionStatus.paid,
        paidAtUtc: DateTime.utc(2026, 10, 31, 22, 30),
      ),
      const Contribution(
        id: 'family-thabo',
        cycleId: _familyCycleId,
        cycleNumber: 1,
        userId: 'thabo',
        memberName: 'Thabo',
        amount: Cents(20_000),
        status: ContributionStatus.pending,
      ),
    ],
  );

  static final _work = Stokvel(
    membership: const Membership(
      stokvelId: 'work-savers',
      role: StokvelRole.member,
    ),
    name: 'Work Savers',
    monthlyContribution: const Cents(100_000),
    memberCount: 1,
    currentPeriod: 1,
    totalPeriods: 12,
    currentCycle: const ContributionCycle(
      id: _workCycleId,
      number: 1,
      status: CycleStatus.open,
      targetAmount: Cents(100_000),
      totalCollected: Cents(30_000),
      amountOutstanding: Cents(70_000),
      dueDate: (year: 2026, month: 11, day: 30),
    ),
    contributions: [
      Contribution(
        id: 'work-lerato',
        cycleId: _workCycleId,
        cycleNumber: 1,
        userId: 'lerato',
        memberName: 'Lerato',
        amount: const Cents(30_000),
        status: ContributionStatus.paid,
        paidAtUtc: DateTime.utc(2026, 10, 18, 10),
      ),
    ],
  );

  @override
  Future<Stokvel?> fetchDetail(String userId, String stokvelId) async {
    final wait = stokvelId == 'work-savers' ? workDelay ?? delay : delay;
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }

    final stokvel = switch ((userId, stokvelId)) {
      ('lerato', 'family-savers') => _family,
      ('nandi', 'family-savers') => _family.copyWith(
        membership: const Membership(
          stokvelId: 'family-savers',
          role: StokvelRole.member,
        ),
      ),
      ('lerato', 'work-savers') => _work,
      _ => null,
    };

    if (failRequests && stokvel != null) {
      throw StateError('Demo detail request failed.');
    }

    return stokvel;
  }
}