import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

typedef CreateStokvelDraft = ({
  String name,
  Cents monthlyContribution,
  int currentPeriod,
  int totalPeriods,
  String? rules,
});

final class EditableCycle {
  const EditableCycle({
    required this.id,
    required this.number,
    required this.target,
    required this.collected,
    required this.version,
    required this.status,
    this.dueDate,
  });

  factory EditableCycle.fromCache(ContributionCycle cycle) {
    final version = cycle.version;

    if (version == null || version <= 0) {
      throw const FormatException('Refresh this cycle before editing.');
    }

    return EditableCycle(
      id: cycle.id,
      number: cycle.number,
      target: cycle.targetAmount,
      collected: cycle.totalCollected,
      version: version,
      status: cycle.status,
      dueDate: cycle.dueDate,
    );
  }

  final String id;
  final int number;
  final Cents target;
  final Cents collected;
  final int version;
  final CycleStatus status;
  final CalendarDate? dueDate;

  EditableCycle preview(int number, Cents target) {
    return EditableCycle(
      id: id,
      number: number,
      target: target,
      collected: collected,
      version: version,
      status: status,
      dueDate: dueDate,
    );
  }
}