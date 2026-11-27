final class FirebaseSettings {
  const new _(this.values);

  factory fromEnvironment() => FirebaseSettings.parse({
    'FIREBASE_API_KEY': const String.fromEnvironment('FIREBASE_API_KEY'),
    'FIREBASE_APP_ID': const String.fromEnvironment('FIREBASE_APP_ID'),
    'FIREBASE_MESSAGING_SENDER_ID': const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    'FIREBASE_PROJECT_ID': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
  });

  factory parse(Map<String, String> input) {
    final values = {for (final key in keys) key: (input[key] ?? '').trim()};

    if (values.values.every((value) => value.isEmpty)) {
      return const FirebaseSettings._({});
    }

    final missing = [
      for (final key in keys)
        if (values[key]!.isEmpty) key,
    ];

    if (missing.isNotEmpty) {
      throw FormatException(
        'Incomplete Firebase configuration. '
        'Missing: ${missing.join(', ')}.',
      );
    }

    return FirebaseSettings._(Map.unmodifiable(values));
  }

  static const keys = [
    'FIREBASE_API_KEY',
    'FIREBASE_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_PROJECT_ID',
  ];

  final Map<String, String> values;

  bool get enabled => values.isNotEmpty;
}
