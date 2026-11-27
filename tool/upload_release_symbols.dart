import 'dart:convert';
import 'dart:io';

import 'release.dart'
    show liveCommand, requiredEnvironment;
import 'release_policy.dart';

Future<void> main() async {
  try {
    requiredEnvironment('SENTRY_AUTH_TOKEN');
    requiredEnvironment('SENTRY_ORG');
    requiredEnvironment('SENTRY_PROJECT');

    final manifest =
        jsonDecode(
              File(
                'release-output/manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    if (manifest['verified'] != true) {
      throw const ReleaseFailure(
        'Upload only a certificate-verified release.',
      );
    }

    for (final value
        in manifest['releases'] as List<dynamic>) {
      final release =
          value as Map<String, dynamic>;

      final symbols = release['symbols'] as String;
      final dartMap = release['dartMap'] as String;

      await liveCommand(
        Platform.resolvedExecutable,
        [
          'run',
          'sentry_dart_plugin',
          '--sentry-define=symbols_path=$symbols',
          '--sentry-define=build_path=$symbols',
          '--sentry-define=dart_symbol_map_path=$dartMap',
          '--sentry-define=upload_sources=false',
          '--sentry-define=upload_source_maps=false',
          '--sentry-define=commits=false',
        ],
        environment: {
          'SENTRY_RELEASE':
              release['release'] as String,
          'SENTRY_DIST':
              release['buildNumber'].toString(),
          'SENTRY_LOG_LEVEL': 'error',
        },
      );
    }
  } on ReleaseFailure catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on Object {
    stderr.writeln('Symbol upload failed.');
    exitCode = 1;
  }
}