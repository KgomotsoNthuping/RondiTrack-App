import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/network/data/api_client.dart';
import 'package:ronditrack/core/network/data/generated/models/member_home_response.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

List<HomeEntry> mapHome(MemberHomeResponse response) {
  return List.unmodifiable([
    for (final item in response.stokvels)
      HomeEntry(
        membership: Membership(
          stokvelId: item.stokvelId,
          role: StokvelRole.fromApi(item.role),
        ),
        name: item.name,
        arrears: Cents(item.arrearsInCents),
        currentCycleNumber: item.currentCycle,
        cycleStatus: item.cycleStatus == null
            ? null
            : CycleStatus.fromApi(item.cycleStatus!),
        cycleDueDate: apiDate(item.cycleDueDate),
        paidThisCycle: item.paidThisCycleInCents == null
            ? null
            : Cents(item.paidThisCycleInCents!),
        stillOwed: item.stillOwedInCents == null
            ? null
            : Cents(item.stillOwedInCents!),
        nextPayoutDateUtc: item.nextPayoutDateUtc?.toUtc(),
      ),
  ]);
}
