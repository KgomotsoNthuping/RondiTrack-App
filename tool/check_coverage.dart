import 'dart:convert';
import 'dart:io';

const coverageReportPath = 'coverage/lcov.info';
const coverageFloorPath = 'tool/coverage_floor.json';

final class LineCoverage {
  new _(this._files);

  factory parse(String source) {
    final files = <String, Map<int, bool>>{};
    String? active;
    var hasRecord = false;

    for (final line in const LineSplitter().convert(source)) {
      if (line.startsWith('SF:')) {
        active = _applicationPath(line.substring(3));
        hasRecord = true;
      } else if (line == 'end_of_record') {
        active = null;
        hasRecord = false;
      } else if (line.startsWith('DA:')) {
        if (!hasRecord) {
          throw const FormatException('Coverage data has no source file.');
        }

        if (active == null) {
          continue;
        }

        final fields = line.substring(3).split(',');
        final number = int.tryParse(fields.first);
        final hits = fields.length >= 2 ? int.tryParse(fields[1]) : null;

        if (number == null || number <= 0 || hits == null || hits < 0) {
          throw const FormatException('Invalid LCOV line coverage.');
        }

        final lines = files.putIfAbsent(active, () => <int, bool>{});
        lines[number] = (lines[number] ?? false) || hits > 0;
      }
    }

    if (files.values.every((lines) => lines.isEmpty)) {
      throw const FormatException('No handwritten lib line coverage found.');
    }

    return LineCoverage._(files);
  }

  final Map<String, Map<int, bool>> _files;

  int get fileCount => _files.length;

  int get totalLines =>
      _files.values.fold(0, (total, lines) => total + lines.length);

  int get coveredLines => _files.values.fold(
    0,
    (total, lines) => total + lines.values.where((covered) => covered).length,
  );

  double get percentage => coveredLines * 100 / totalLines;

  bool meets(double minimum) => percentage + 0.000000001 >= minimum;
}

String? _applicationPath(String source) {
  var path = source.trim().replaceAll('\\', '/');

  if (!path.startsWith('lib/')) {
    final position = path.indexOf('/lib/');

    if (position < 0) {
      return null;
    }

    path = path.substring(position + 1);
  }

  if (!path.endsWith('.dart') ||
      path.split('/').contains('..') ||
      path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.startsWith('lib/core/network/data/generated/')) {
    return null;
  }

  return path;
}

double readCoverageFloor(String source) {
  final json = jsonDecode(source);

  if (json is! Map<String, dynamic> || json['schema'] != 1) {
    throw const FormatException('Invalid coverage floor file.');
  }

  final value = json['minimum_percent'];

  if (value is! num || !value.isFinite || value < 0 || value > 100) {
    throw const FormatException('Coverage floor must be between 0 and 100.');
  }

  return value.toDouble();
}

Future<void> main(List<String> arguments) async {
  if (arguments.isNotEmpty &&
      (arguments.length != 1 || arguments.single != '--record-baseline')) {
    stderr.writeln(
      'Usage: dart run tool/check_coverage.dart [--record-baseline]',
    );
    exitCode = 64;
    return;
  }

  try {
    final report = LineCoverage.parse(
      await File(coverageReportPath).readAsString(),
    );
    final floorFile = File(coverageFloorPath);

    if (arguments.isNotEmpty) {
      if (Platform.environment.containsKey('CI')) {
        throw StateError('CI must check an existing floor.');
      }

      if (await floorFile.exists()) {
        throw StateError(
          'A floor already exists. Run the normal coverage check.',
        );
      }

      final candidate = (report.percentage - 2) * 10;
      final minimum = candidate < 0 ? 0.0 : candidate.floorToDouble() / 10;
      final recordedAt = DateTime.now().toUtc().toIso8601String();

      final baseline = {
        'schema': 1,
        'recorded_at_utc': recordedAt,
        'measured_percent': report.percentage,
        'minimum_percent': minimum,
        'covered_lines': report.coveredLines,
        'total_lines': report.totalLines,
        'reported_files': report.fileCount,
        'excluded': [
          '*.g.dart',
          '*.freezed.dart',
          'lib/core/network/data/generated/',
        ],
      };

      await floorFile.parent.create(recursive: true);

      final encoded = const JsonEncoder.withIndent('  ').convert(baseline);
      await floorFile.writeAsString('$encoded\n');

      final evidence = File('docs/coverage_baseline.md');
      await evidence.parent.create(recursive: true);
      await evidence.writeAsString(
        '# Coverage baseline\n\n'
        'Recorded: $recordedAt\n\n'
        '| Measure | Result |\n'
        '| --- | --- |\n'
        '| Covered lines | ${report.coveredLines} |\n'
        '| Reported handwritten lines | ${report.totalLines} |\n'
        '| Reported handwritten files | ${report.fileCount} |\n'
        '| Measured coverage | ${report.percentage.toStringAsFixed(2)}% |\n'
        '| Enforced floor | ${minimum.toStringAsFixed(1)}% |\n\n'
        'The floor is rounded down to one decimal place, '
        'approximately two percentage points below this measured baseline.\n\n'
        'Only reported Dart files under lib are counted. Generated .g.dart, '
        '.freezed.dart and lib/core/network/data/generated/ files are excluded. '
        'Handwritten session, cache, payment and failure code remains included.\n',
      );
    }

    if (!await floorFile.exists()) {
      throw StateError(
        'No coverage floor. Run flutter test --coverage, then '
        'dart run tool/check_coverage.dart --record-baseline locally.',
      );
    }

    final minimum = readCoverageFloor(await floorFile.readAsString());

    stdout.writeln(
      '${report.coveredLines}/${report.totalLines} handwritten lines: '
      '${report.percentage.toStringAsFixed(2)}%; '
      'floor ${minimum.toStringAsFixed(1)}%.',
    );

    if (!report.meets(minimum)) {
      stderr.writeln('Coverage is below the committed floor.');
      exitCode = 1;
    }
  } on Object catch (error) {
    stderr.writeln('Coverage check failed: $error');
    exitCode = 1;
  }
}
