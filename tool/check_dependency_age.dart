import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  Map<String, String> packages;

  try {
    packages = _hostedPackages(await File('pubspec.lock').readAsLines());
  } on Object {
    stderr.writeln(
      'Cannot read hosted dependencies. Run flutter pub get first.',
    );
    exitCode = 1;
    return;
  }

  final entries = packages.entries.toList();
  final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 14));

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..maxConnectionsPerHost = 4;

  final issues = <String>[];
  var next = 0;
  var registryFailed = false;

  Future<void> worker() async {
    while (!registryFailed && next < entries.length) {
      final entry = entries[next++];
      final uri = Uri.https(
        'pub.dev',
        '/api/packages/${entry.key}/versions/${entry.value}',
      );

      try {
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 15));

        final response = await request.close().timeout(
          const Duration(seconds: 15),
        );

        if (response.statusCode != HttpStatus.ok) {
          throw const FormatException('Package metadata unavailable.');
        }

        final body = await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 15));

        final decoded = jsonDecode(body) as Map<String, dynamic>;

        if (decoded['version'] != entry.value) {
          throw const FormatException('Package version mismatch.');
        }

        final published = DateTime.parse(decoded['published'] as String)
            .toUtc();

        if (published.isAfter(cutoff)) {
          issues.add(
            '${entry.key} ${entry.value}: '
            'published ${published.toIso8601String()}, under 14 days old.',
          );
        }
      } on Object catch (error) {
        registryFailed = true;
        issues.add(
          '${entry.key} ${entry.value}: '
          'metadata check failed (${error.runtimeType}).',
        );
      }
    }
  }

  try {
    await Future.wait(List.generate(4, (_) => worker()));
  } finally {
    client.close(force: true);
  }

  if (issues.isNotEmpty) {
    issues.sort();
    stderr.writeln(issues.join('\n'));
    exitCode = 1;
    return;
  }

  stdout.writeln(
    '${packages.length} hosted dependencies checked: '
    'every resolved version is at least 14 days old.',
  );
}

Map<String, String> _hostedPackages(List<String> lines) {
  final result = <String, String>{};
  final heading = RegExp(r'^  ([a-zA-Z0-9_]+):$');

  String? name;
  String? source;
  String? version;
  var reading = false;

  void finish() {
    if (name != null && source == 'hosted') {
      if (version == null || version!.isEmpty) {
        throw const FormatException('Missing dependency version.');
      }

      result[name!] = version!;
    }
  }

  for (final line in lines) {
    if (line == 'packages:') {
      reading = true;
      continue;
    }

    if (!reading) {
      continue;
    }

    if (line.isNotEmpty && !line.startsWith(' ')) {
      finish();
      name = null;
      break;
    }

    final match = heading.firstMatch(line);

    if (match != null) {
      finish();
      name = match.group(1);
      source = null;
      version = null;
      continue;
    }

    if (line.startsWith('    source: ')) {
      source = line.substring('    source: '.length).trim();
    }

    if (line.startsWith('    version: ')) {
      version = line
          .substring('    version: '.length)
          .trim()
          .replaceAll('"', '')
          .replaceAll("'", '');
    }
  }

  finish();

  if (result.isEmpty) {
    throw const FormatException('No hosted dependencies found.');
  }

  return result;
}
