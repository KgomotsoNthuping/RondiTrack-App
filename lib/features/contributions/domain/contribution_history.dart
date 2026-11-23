import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/dates/south_african_dates.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

typedef SelectedDays = ({CalendarDate first, CalendarDate last});

typedef HistoryFilter = ({
  String? cycleId,
  ContributionStatus? status,
  String? memberId,
  SelectedDays? days,
});

const HistoryFilter allContributions = (
  cycleId: null,
  status: null,
  memberId: null,
  days: null,
);

extension HistoryFilterRules on HistoryFilter {
  bool get active =>
      cycleId != null || status != null || memberId != null || days != null;

  bool matches(Contribution item) {
    if (cycleId != null &&
        item.cycleId.toLowerCase() != cycleId!.toLowerCase()) {
      return false;
    }

    if (status != null && item.status != status) {
      return false;
    }

    if (memberId != null &&
        item.userId.toLowerCase() != memberId!.toLowerCase()) {
      return false;
    }

    final selected = days;

    if (selected != null) {
      final paid = item.paidAtUtc?.toUtc();

      if (paid == null) {
        return false;
      }

      final bounds = southAfricanDateRange(
        firstDay: selected.first,
        lastDay: selected.last,
      );

      if (paid.isBefore(bounds.fromInclusive) ||
          !paid.isBefore(bounds.toExclusive)) {
        return false;
      }
    }

    return true;
  }
}

final class HistoryPage {
  const new(this.items, this.nextToken);

  final List<Contribution> items;
  final String? nextToken;
}

typedef HistoryOptions = ({
  List<({String id, int number})> cycles,
  List<({String id, String name})> members,
});

const HistoryOptions emptyHistoryOptions = (cycles: [], members: []);
