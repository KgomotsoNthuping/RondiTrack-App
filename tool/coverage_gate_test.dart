import 'package:flutter_test/flutter_test.dart';

import 'check_coverage.dart';

void main() {
  test('merges duplicate records and normalises Windows paths', () {
    final report = LineCoverage.parse(r'''
SF:lib/core/errors/failure.dart
DA:1,1
DA:2,0
end_of_record
SF:C:\Repos\RondiTrack-App\lib\core\errors\failure.dart
DA:1,0
DA:2,1
DA:3,0
end_of_record
''');

    expect(report.fileCount, 1);
    expect(report.totalLines, 3);
    expect(report.coveredLines, 2);
    expect(report.percentage, closeTo(66.666666, 0.00001));
    expect(report.meets(66.6), isTrue);
    expect(report.meets(66.7), isFalse);
  });

  test('excludes generated code while counting handwritten hard files', () {
    final report = LineCoverage.parse('''
SF:lib/core/session/session_coordinator.dart
DA:1,0
end_of_record
SF:lib/features/payments/application/payment_worker.dart
DA:1,1
end_of_record
SF:lib/core/offline/data/app_database.g.dart
DA:1,1
end_of_record
SF:lib/features/home/domain/home_entry.freezed.dart
DA:1,1
end_of_record
SF:lib/core/network/data/generated/client.dart
DA:1,1
end_of_record
SF:test/fixture.dart
DA:1,1
end_of_record
''');

    expect(report.fileCount, 2);
    expect(report.totalLines, 2);
    expect(report.coveredLines, 1);
    expect(report.percentage, 50);
    expect(report.meets(50), isTrue);
    expect(report.meets(50.1), isFalse);
  });

  for (final source in [
    '',
    'SF:lib/generated.g.dart\nDA:1,1\nend_of_record',
    'DA:1,1\nend_of_record',
    'SF:lib/main.dart\nDA:0,1\nend_of_record',
    'SF:lib/main.dart\nDA:1,-1\nend_of_record',
  ]) {
    test('empty or malformed coverage is refused: $source', () {
      expect(() => LineCoverage.parse(source), throwsFormatException);
    });
  }

  test('reads a saved floor without replacing it', () {
    expect(readCoverageFloor('{"schema":1,"minimum_percent":72.4}'), 72.4);
  });

  for (final source in [
    '{}',
    '{"schema":1,"minimum_percent":-1}',
    '{"schema":1,"minimum_percent":101}',
    '{"schema":1,"minimum_percent":"72.4"}',
  ]) {
    test('invalid floor is refused: $source', () {
      expect(() => readCoverageFloor(source), throwsFormatException);
    });
  }
}
