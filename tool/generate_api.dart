import 'dart:io';

const _outputPath = 'lib/core/network/data/generated';

Future<void> main() async {
  for (final path in [
    'pubspec.yaml',
    'swagger_parser.yaml',
    'contract/openapi/v1.json',
  ]) {
    if (!File(path).existsSync()) {
      throw StateError('Required file missing: $path. Run from the app root.');
    }
  }

  final output = Directory(_outputPath);
  if (output.existsSync()) {
    output.deleteSync(recursive: true);
  }

  const commands = <List<String>>[
    ['run', 'swagger_parser'],
    ['run', 'build_runner', 'build'],
    ['format', _outputPath],
  ];

  for (final arguments in commands) {
    final process = await Process.start(
      Platform.resolvedExecutable,
      arguments,
      mode: ProcessStartMode.inheritStdio,
    );
    final result = await process.exitCode;

    if (result != 0) {
      exitCode = result;
      return;
    }
  }
}
