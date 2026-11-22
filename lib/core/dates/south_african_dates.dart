import 'package:ronditrack/core/dates/calendar_date.dart';

const _southAfricanOffset = Duration(hours: 2);

typedef SouthAfricanUtcRange = ({DateTime fromInclusive, DateTime toExclusive});

CalendarDate southAfricanCalendarDay(DateTime instant) {
  final southAfricanTime = instant.toUtc().add(_southAfricanOffset);

  return (
    year: southAfricanTime.year,
    month: southAfricanTime.month,
    day: southAfricanTime.day,
  );
}

SouthAfricanUtcRange southAfricanDateRange({
  required CalendarDate firstDay,
  required CalendarDate lastDay,
}) {
  final first = _validatedDay(firstDay);
  final last = _validatedDay(lastDay);

  if (last.isBefore(first)) {
    throw ArgumentError.value(
      lastDay,
      'lastDay',
      'Must be on or after firstDay.',
    );
  }

  return (
    fromInclusive: first.subtract(_southAfricanOffset),
    toExclusive: last
        .add(const Duration(days: 1))
        .subtract(_southAfricanOffset),
  );
}

DateTime _validatedDay(CalendarDate date) {
  final value = DateTime.utc(date.year, date.month, date.day);

  if (value.year != date.year ||
      value.month != date.month ||
      value.day != date.day) {
    throw ArgumentError.value(date, 'date', 'Must be a valid calendar date.');
  }

  return value;
}
