import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/domain/home_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

final class FakeHomeRepository implements HomeRepository {
    const new({
    this.delay = const Duration(milliseconds: 350),
    this.nalediJoinedFamily = false,
  });

  final Duration delay;
  final bool nalediJoinedFamily;

  static final _payout = DateTime.utc(2026, 11, 30);
  static const ({int day, int month, int year}) _familyDue = (
    year: 2026,
    month: 10,
    day: 31,
  );

  static final _lerato = List<HomeEntry>.unmodifiable([
    HomeEntry(
      membership: const Membership(
        stokvelId: 'family-savers',
        role: StokvelRole.treasurer,
      ),
      name: 'Family Savers',
      arrears: const Cents(0),
      currentCycleNumber: 1,
      cycleStatus: CycleStatus.open,
      cycleDueDate: _familyDue,
      paidThisCycle: const Cents(50_000),
      stillOwed: const Cents(0),
      nextPayoutDateUtc: _payout,
    ),
    HomeEntry(
      membership: const Membership(
        stokvelId: 'work-savers',
        role: StokvelRole.member,
      ),
      name: 'Work Savers',
      arrears: const Cents(0),
      currentCycleNumber: 1,
      cycleStatus: CycleStatus.open,
      cycleDueDate: (year: 2026, month: 11, day: 30),
      paidThisCycle: const Cents(30_000),
      stillOwed: const Cents(70_000),
      nextPayoutDateUtc: _payout,
    ),
  ]);

  static final _nandi = List<HomeEntry>.unmodifiable([
    HomeEntry(
      membership: const Membership(
        stokvelId: 'family-savers',
        role: StokvelRole.member,
      ),
      name: 'Family Savers',
      arrears: const Cents(0),
      currentCycleNumber: 1,
      cycleStatus: CycleStatus.open,
      cycleDueDate: _familyDue,
      paidThisCycle: const Cents(10),
      stillOwed: const Cents(49_990),
      nextPayoutDateUtc: _payout,
    ),
  ]);

    static final _naledi = List<HomeEntry>.unmodifiable([
    _nandi.single.copyWith(
      paidThisCycle: const Cents(0),
      stillOwed: const Cents(50_000),
    ),
  ]);

  @override
  Future<List<HomeEntry>> fetchHome(String userId) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    return switch (userId) {
      'lerato' => _lerato,
      'nandi' => _nandi,
      'naledi' => nalediJoinedFamily ? _naledi : const <HomeEntry>[],
      _ => throw StateError('Unknown demo profile.'),
    };
  }
}
