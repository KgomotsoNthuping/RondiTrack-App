import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/network/data/api_client.dart';
import 'package:ronditrack/core/network/data/generated/models/contribution_cycle_response.dart';
import 'package:ronditrack/core/network/data/generated/models/paged_response_of_contribution_list_item_response.dart';
import 'package:ronditrack/core/network/data/generated/models/stokvel.dart'
    as api;
import 'package:ronditrack/core/pagination/page.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

ContributionCycle mapCycle(ContributionCycleResponse response) {
  return ContributionCycle(
    id: response.id,
    number: response.cycleNumber,
    status: CycleStatus.fromApi(response.status),
    targetAmount: apiRand(response.targetAmount),
    totalCollected: Cents(response.totalCollectedInCents),
    amountOutstanding: Cents(response.amountDueInCents),
    dueDate: apiDate(response.dueDate),
    version: response.version,
  );
}

Page<Contribution> mapContributions(
  PagedResponseOfContributionListItemResponse response, {
  required String userId,
  required String memberName,
}) {
  return Page(
    items: [
      for (final item in response.items)
        Contribution(
          id: item.id,
          cycleId: item.contributionCycleId,
          cycleNumber: item.cycleNumber,
          userId: userId,
          memberName: memberName,
          amount: Cents(item.amountInCents),
          status: ContributionStatus.fromApi(item.status),
          paidAtUtc: item.paidAtUtc?.toUtc(),
        ),
    ],
    nextPageToken: apiNextPageToken(response.nextPageToken),
  );
}

Stokvel mapStokvel(
  api.Stokvel response, {
  required Membership membership,
  required int memberCount,
  required List<Contribution> contributions,
  ContributionCycleResponse? cycle,
}) {
  return Stokvel(
    membership: membership,
    name: response.name,
    monthlyContribution: apiRand(response.monthlyContribution),
    memberCount: memberCount,
    currentPeriod: response.currentPeriod,
    totalPeriods: response.totalPeriods,
    contributions: contributions,
    currentCycle: cycle == null ? null : mapCycle(cycle),
    rules: response.rules,
    version: response.version,
  );
}
