import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

part 'stokvel.freezed.dart';

@freezed
abstract class Membership with _$Membership {
  const factory({required String stokvelId, required StokvelRole role}) =
      _Membership;
}

@freezed
abstract class Stokvel with _$Stokvel {
  const factory({
    required Membership membership,
    required String name,
    required Cents monthlyContribution,
    required int memberCount,
    required int currentPeriod,
    required int totalPeriods,
    required List<Contribution> contributions,
    ContributionCycle? currentCycle,
    String? rules,
  }) = _Stokvel;
}

@freezed
abstract class ContributionCycle with _$ContributionCycle {
  const factory({
    required String id,
    required int number,
    required CycleStatus status,
    required Cents targetAmount,
    required Cents totalCollected,
    required Cents amountOutstanding,
    CalendarDate? dueDate,
  }) = _ContributionCycle;
}

@freezed
abstract class Contribution with _$Contribution {
  const factory({
    required String id,
    required String cycleId,
    required int cycleNumber,
    required String userId,
    required String memberName,
    required Cents amount,
    required ContributionStatus status,
    DateTime? paidAtUtc,
  }) = _Contribution;
}
