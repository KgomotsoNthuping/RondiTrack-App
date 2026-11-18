import 'dart:io';

const _outputPath = 'lib/core/network/data/generated';

Future<void> main() async {
  final generation = await Process.start(Platform.resolvedExecutable, [
    'run',
    'tool/generate_api.dart',
  ], mode: ProcessStartMode.inheritStdio);
  final generationResult = await generation.exitCode;

  if (generationResult != 0) {
    exitCode = generationResult;
    return;
  }

  final differences = await Process.run('git', [
    'diff',
    '--quiet',
    'HEAD',
    '--',
    _outputPath,
  ]);

  if (differences.exitCode != 0) {
    stderr.writeln(
      'The generated API client differs from the committed files.',
    );
    exitCode = 1;
    return;
  }

  final untracked = await Process.run('git', [
    'ls-files',
    '--others',
    '--',
    _outputPath,
  ]);

  if (untracked.exitCode != 0) {
    stderr.write(untracked.stderr);
    exitCode = untracked.exitCode;
    return;
  }

  final newFiles = untracked.stdout.toString().trim();
  if (newFiles.isNotEmpty) {
    stderr.writeln('The generator produced untracked files:');
    stderr.writeln(newFiles);
    exitCode = 1;
    return;
  }

  stdout.writeln('The generated API client matches the committed files.');
}
