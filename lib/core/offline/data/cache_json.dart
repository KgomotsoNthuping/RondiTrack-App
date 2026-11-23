import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';

Map<String, Object?> cacheObject(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Invalid cached object.');
  }

  return value;
}

List<Object?> cacheList(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException('Invalid cached list.');
  }

  return value;
}

List<int>? cacheDateToJson(CalendarDate? date) {
  if (date == null) {
    return null;
  }

  return [date.year, date.month, date.day];
}

CalendarDate? cacheDateFromJson(Object? value) {
  if (value == null) {
    return null;
  }

  final parts = cacheList(value);

  if (parts.length != 3) {
    throw const FormatException('Invalid cached calendar date.');
  }

  return (
    year: parts[0]! as int,
    month: parts[1]! as int,
    day: parts[2]! as int,
  );
}

DateTime? cacheInstantFromJson(Object? value) {
  return value == null ? null : DateTime.parse(value as String).toUtc();
}

Cents? cacheCentsFromJson(Object? value) {
  return value == null ? null : Cents(value as int);
}

DateTime cacheTimestamp(int milliseconds) {
  return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}
