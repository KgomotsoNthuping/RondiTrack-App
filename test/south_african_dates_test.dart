import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/dates/south_african_dates.dart';

void main() {
  group('South African dates', () {
    test('one selected day becomes half-open UTC bounds', () {
      final range = southAfricanDateRange(
        firstDay: (year: 2026, month: 11, day: 1),
        lastDay: (year: 2026, month: 11, day: 1),
      );

      expect(range.fromInclusive, DateTime.utc(2026, 10, 31, 22));
      expect(range.toExclusive, DateTime.utc(2026, 11, 1, 22));
    });

    test('00:30 SAST belongs to 1 November', () {
      final contribution = DateTime.parse('2026-11-01T00:30:00+02:00');

      final range = southAfricanDateRange(
        firstDay: (year: 2026, month: 11, day: 1),
        lastDay: (year: 2026, month: 11, day: 1),
      );

      expect(contribution, DateTime.utc(2026, 10, 31, 22, 30));
      expect(southAfricanCalendarDay(contribution), (
        year: 2026,
        month: 11,
        day: 1,
      ));
      expect(contribution.isBefore(range.fromInclusive), isFalse);
      expect(contribution.isBefore(range.toExclusive), isTrue);
    });

    test('the exclusive end belongs to the following day', () {
      final range = southAfricanDateRange(
        firstDay: (year: 2026, month: 11, day: 1),
        lastDay: (year: 2026, month: 11, day: 1),
      );

      expect(southAfricanCalendarDay(range.toExclusive), (
        year: 2026,
        month: 11,
        day: 2,
      ));
    });

    test('a range includes the entire final selected day', () {
      final range = southAfricanDateRange(
        firstDay: (year: 2026, month: 10, day: 31),
        lastDay: (year: 2026, month: 11, day: 2),
      );

      expect(range.fromInclusive, DateTime.utc(2026, 10, 30, 22));
      expect(range.toExclusive, DateTime.utc(2026, 11, 2, 22));
    });

    test('leap day is valid', () {
      final range = southAfricanDateRange(
        firstDay: (year: 2024, month: 2, day: 29),
        lastDay: (year: 2024, month: 2, day: 29),
      );

      expect(range.fromInclusive, DateTime.utc(2024, 2, 28, 22));
      expect(range.toExclusive, DateTime.utc(2024, 2, 29, 22));
    });

    test('invalid calendar dates are rejected', () {
      expect(
        () => southAfricanDateRange(
          firstDay: (year: 2026, month: 2, day: 30),
          lastDay: (year: 2026, month: 3, day: 1),
        ),
        throwsArgumentError,
      );
    });

    test('reversed ranges are rejected', () {
      expect(
        () => southAfricanDateRange(
          firstDay: (year: 2026, month: 11, day: 2),
          lastDay: (year: 2026, month: 11, day: 1),
        ),
        throwsArgumentError,
      );
    });
  });
}
