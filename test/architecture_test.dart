import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
final _quotedUri = RegExp(r'''['"]([^'"]+)['"]''');
final _dataPackage = RegExp(r'^package:(?:dio|drift|drift_flutter)/');
final _stringsAndComments = RegExp(
  r'''('(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")'''
  r'|(//[^\r\n]*|/\*[\s\S]*?\*/)',
);
final _nonNewline = RegExp(r'[^\r\n]');

void main() {
  final sources = {
    for (final file in Directory(
      'lib/features',
    ).listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart'))
        file.path.replaceAll('\\', '/'): _removeComments(
          file.readAsStringSync(),
        ),
  };

  test('feature files take colours from the theme', () {
    expect(sources, isNotEmpty);

    final violations = <String>[
      for (final MapEntry(key: path, value: source) in sources.entries)
        for (final match in _inlineColour.allMatches(source))
          '$path:${_line(source, match.start)} ${match[0]}',
    ];

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('presentation avoids data imports', () {
    final violations = <String>[];

    for (final MapEntry(key: path, value: source) in sources.entries) {
      if (!path.contains('/presentation/') && !path.endsWith('_screen.dart')) {
        continue;
      }

      for (final directive in _directive.allMatches(source)) {
        for (final match in _quotedUri.allMatches(directive[0]!)) {
          final uri = match[1]!;
          if (_dataPackage.hasMatch(uri) || uri.split('/').contains('data')) {
            final line = _line(source, directive.start + match.start);
            violations.add('$path:$line $uri');
          }
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

String _removeComments(String source) {
  return source.replaceAllMapped(
    _stringsAndComments,
    (match) => match[1] ?? match[0]!.replaceAll(_nonNewline, ' '),
  );
}

int _line(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}
