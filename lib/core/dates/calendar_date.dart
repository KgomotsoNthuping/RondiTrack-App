typedef CalendarDate = ({int year, int month, int day});

/// Formats a date without applying a time zone.
String formatCalendarDate(CalendarDate date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Displays an instant using Johannesburg's UTC+02 time.
String formatJohannesburgDate(DateTime instant, {bool includeTime = false}) {
  final local = instant.toUtc().add(const Duration(hours: 2));
  final date = formatCalendarDate((
    year: local.year,
    month: local.month,
    day: local.day,
  ));

  if (!includeTime) {
    return date;
  }

  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$date $hour:$minute';
}
