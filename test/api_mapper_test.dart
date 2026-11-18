import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/network/data/generated/models/contribution_cycle_response.dart';
import 'package:ronditrack/core/network/data/generated/models/member_home_response.dart';
import 'package:ronditrack/core/network/data/generated/models/paged_response_of_contribution_list_item_response.dart';
import 'package:ronditrack/features/home/data/home_mapper.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_mapper.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

void main() {
  test('home maps roles, cents, calendar dates and UTC instants', () {
    final response = MemberHomeResponse.fromJson({
      'stokvels': [
        {
          'stokvelId': 'family',
          'name': 'Family Savers',
          'role': 'Treasurer',
          'currentCycle': 1,
          'cycleStatus': 'Open',
          'cycleDueDate': '2026-10-31',
          'paidThisCycleInCents': 50010,
          'stillOwedInCents': 0,
          'nextPayoutDateUtc': '2026-11-30T00:30:00+02:00',
          'arrearsInCents': 10,
        },
      ],
    });

    final entry = mapHome(response).single;

    expect(entry.membership.role, StokvelRole.treasurer);
    expect(entry.cycleStatus, CycleStatus.open);
    expect(entry.paidThisCycle?.value, 50010);
    expect(entry.arrears.value, 10);
    expect(entry.cycleDueDate, (year: 2026, month: 10, day: 31));
    expect(entry.nextPayoutDateUtc, DateTime.utc(2026, 11, 29, 22, 30));
    expect(entry.nextPayoutDateUtc?.isUtc, isTrue);
  });

  test('new cycle statuses become unknown and versions stay exact', () {
    final response = ContributionCycleResponse.fromJson({
      'id': 'cycle',
      'stokvelId': 'family',
      'cycleNumber': 1,
      'targetAmount': 1500.30,
      'version': 4294967295,
      'status': 'FutureStatus',
      'dueDate': '2026-10-31',
      'totalCollectedInCents': 50010,
      'amountDueInCents': 100020,
    });

    final cycle = mapCycle(response);

    expect(cycle.status, CycleStatus.unknown);
    expect(cycle.targetAmount.value, 150030);
    expect(cycle.totalCollected.value, 50010);
    expect(cycle.amountOutstanding.value, 100020);
    expect(cycle.version, 4294967295);
    expect(cycle.dueDate, (year: 2026, month: 10, day: 31));
  });

  test('contributions preserve cents and normalize the end marker', () {
    final response = PagedResponseOfContributionListItemResponse.fromJson({
      'items': [
        {
          'id': 'contribution',
          'contributionCycleId': 'cycle',
          'amountInCents': 10,
          'status': 'FutureStatus',
          'paidAtUtc': '2026-10-31T22:30:00Z',
          'cycleNumber': 1,
        },
      ],
      'nextPageToken': '',
    });

    final page = mapContributions(
      response,
      userId: 'user',
      memberName: 'Lerato',
    );

    expect(page.hasMore, isFalse);
    expect(page.nextPageToken, isNull);
    expect(page.items.single.amount.value, 10);
    expect(page.items.single.status, ContributionStatus.unknown);
    expect(page.items.single.userId, 'user');
    expect(page.items.single.paidAtUtc?.isUtc, isTrue);
  });
}
