import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

part 'home_entry.freezed.dart';

@freezed
abstract class HomeEntry with _$HomeEntry {
  const factory({
    required Membership membership,
    required String name,
    required Cents arrears,
    int? currentCycleNumber,
    CycleStatus? cycleStatus,
    CalendarDate? cycleDueDate,
    Cents? paidThisCycle,
    Cents? stillOwed,
    DateTime? nextPayoutDateUtc,
  }) = _HomeEntry;
}
