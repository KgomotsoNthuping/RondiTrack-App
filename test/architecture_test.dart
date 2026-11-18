import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _libRoot = Directory.current.uri.resolve('lib/');

final _inlineColour = RegExp(
  r'\b(?:Color|MaterialColor|MaterialAccentColor|ColorSwatch)'
  r'(?:\s*\.\s*(?:new|from\w*))?\s*\('
  r'|\b(?:Colors|CupertinoColors)\s*\.\s*\w+'
  r'|\b0[xX][A-Fa-f0-9]{6,8}\b',
);

final _directive = RegExp(
  r'^[ \t]*(?:import|export)\s+[^;]+;',
  multiLine: true,
);

final _exportDirective = RegExp(
  r'^[ \t]*export\s+[^;]+;',
  multiLine: true,
);

final _quotedUri = RegExp(r'''['"]([^'"]+)['"]''');

final _networkPackage = RegExp(
  r'^package:(?:dio|retrofit|drift|drift_flutter)/',
);

final _stringsAndComments = RegExp(
  r'''('(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")'''
  r'|(//[^\r\n]*|/\*[\s\S]*?\*/)',
);

final _nonNewline = RegExp(r'[^\r\n]');

void main() {
  final sources = <Uri, String>{
    for (final file
        in Directory('lib').listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart') &&
          !file.path.endsWith('.g.dart') &&
          !file.path.endsWith('.freezed.dart') &&
          !file.path.replaceAll('\\', '/').contains('/generated/'))
        file.absolute.uri: _removeComments(file.readAsStringSync()),
  };

  test('feature colours come from the theme', () {
    final violations = <String>[];

    for (final entry in sources.entries) {
      final path = _path(entry.key);

      if (!path.startsWith('features/')) {
        continue;
      }

      for (final match in _inlineColour.allMatches(entry.value)) {
        violations.add(
          'lib/$path:${_line(entry.value, match.start)} ${match[0]}',
        );
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('presentation and domain avoid data dependencies', () {
    final violations = <String>[];

    for (final entry in sources.entries) {
      final path = _path(entry.key);

      if (!path.contains('/presentation/') &&
          !path.contains('/domain/') &&
          !path.endsWith('_screen.dart')) {
        continue;
      }

      for (final dependency in _uris(entry.value)) {
        final forbidden = _dataDependency(dependency.value) ||
            _exportsData(
              _resolve(entry.key, dependency.value),
              sources,
              <Uri>{},
            );

        if (forbidden) {
          violations.add(
            'lib/$path:${_line(entry.value, dependency.offset)} '
            '${dependency.value}',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('network packages and generated clients stay in data', () {
    final violations = <String>[];

    for (final entry in sources.entries) {
      final path = _path(entry.key);

      if (path.split('/').contains('data')) {
        continue;
      }

      for (final dependency in _uris(entry.value)) {
        if (_networkPackage.hasMatch(dependency.value) ||
            dependency.value.split('/').contains('generated')) {
          violations.add('lib/$path: ${dependency.value}');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

String _path(Uri uri) {
  return uri.path.substring(_libRoot.path.length);
}

bool _dataDependency(String uri) {
  final segments = uri.split('/');

  return _networkPackage.hasMatch(uri) ||
      segments.contains('data') ||
      segments.contains('generated');
}

Iterable<({String value, int offset})> _uris(
  String source, {
  bool exportsOnly = false,
}) sync* {
  final pattern = exportsOnly ? _exportDirective : _directive;

  for (final directive in pattern.allMatches(source)) {
    for (final match in _quotedUri.allMatches(directive[0]!)) {
      yield (
        value: match[1]!,
        offset: directive.start + match.start,
      );
    }
  }
}

Uri? _resolve(Uri source, String dependency) {
  const prefix = 'package:ronditrack/';

  if (dependency.startsWith(prefix)) {
    return _libRoot.resolve(dependency.substring(prefix.length));
  }

  final parsed = Uri.tryParse(dependency);

  if (parsed == null || parsed.hasScheme) {
    return null;
  }

  return source.resolveUri(parsed);
}

bool _exportsData(
  Uri? uri,
  Map<Uri, String> sources,
  Set<Uri> seen,
) {
  if (uri == null || !seen.add(uri)) {
    return false;
  }

  final source = sources[uri];

  if (source == null) {
    return false;
  }

  for (final dependency in _uris(source, exportsOnly: true)) {
    if (_dataDependency(dependency.value) ||
        _exportsData(
          _resolve(uri, dependency.value),
          sources,
          seen,
        )) {
      return true;
    }
  }

  return false;
}

String _removeComments(String source) {
  return source.replaceAllMapped(
    _stringsAndComments,
    (match) =>
        match[1] ?? match[0]!.replaceAll(_nonNewline, ' '),
  );
}

int _line(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}