import 'dart:io';

final class ReleaseFailure implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ReleaseIdentity {
  const new _(this.tag, this.version, this.buildNumber);

  factory create(String tag, int runNumber, int attempt) {
    final valid = RegExp(
      r'^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$',
    );
    if (tag.trim() != tag ||
        !valid.hasMatch(tag) ||
        runNumber < 1 ||
        attempt < 1 ||
        attempt > 99) {
      throw const ReleaseFailure(
        'Use a vX.Y.Z tag and valid CI run/attempt numbers.',
      );
    }
    final build = runNumber * 100 + attempt;
    if (build > 2100000000) {
      throw const ReleaseFailure(
        'The generated Android build number is too large.',
      );
    }
    return ReleaseIdentity._(tag, tag.substring(1), build);
  }

  final String tag;
  final String version;
  final int buildNumber;

  String appId(String flavor) => switch (flavor) {
    'staging' => 'za.co.kgomotsonthuping.ronditrack.staging',
    'prod' => 'za.co.kgomotsonthuping.ronditrack',
    _ => throw const ReleaseFailure('Release only staging and prod.'),
  };

  String release(String flavor) => '${appId(flavor)}@$version+$buildNumber';
}

String normalizeFingerprint(String value) {
  final normalized = value.replaceAll(RegExp(r'[:\s]'), '').toUpperCase();
  if (!RegExp(r'^[0-9A-F]{64}$').hasMatch(normalized)) {
    throw const ReleaseFailure(
      'Set the real SHA-256 upload certificate fingerprint.',
    );
  }
  return normalized;
}

String certificateFingerprint(String output, {bool apk = false}) {
  final pattern = apk
      ? RegExp(r'certificate SHA-256 digest:\s*([0-9a-fA-F]+)')
      : RegExp(r'SHA256:\s*([0-9a-fA-F:]+)');
  final matches = pattern.allMatches(output).toList();
  if (matches.length != 1) {
    throw const ReleaseFailure('Expected one signing certificate.');
  }
  return normalizeFingerprint(matches.single[1]!);
}

void verifyFingerprint(String actual, String expected) {
  if (normalizeFingerprint(actual) != normalizeFingerprint(expected)) {
    throw const ReleaseFailure(
      'Certificate does not match the upload key. Release refused.',
    );
  }
}

Map<String, String> readSigningProperties(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw const ReleaseFailure(
      'Missing private key.properties. Set ANDROID_KEY_PROPERTIES or create android/key.properties.',
    );
  }
  final result = <String, String>{};
  for (final source in file.readAsLinesSync()) {
    final line = source.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final split = line.indexOf('=');
    if (split < 1) {
      throw const ReleaseFailure('Invalid private signing properties.');
    }
    final key = line.substring(0, split).trim();
    final value = line.substring(split + 1).trim();
    if (!const ['storeFile', 'keyAlias'].contains(key) ||
        result.containsKey(key) ||
        value.isEmpty ||
        value.contains(r'\')) {
      throw const ReleaseFailure(
        'Use only storeFile with forward slashes and keyAlias.',
      );
    }
    result[key] = value;
  }
  if (result.length != 2 ||
      !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(result['keyAlias'] ?? '')) {
    throw const ReleaseFailure('Configure storeFile and a valid keyAlias.');
  }
  return result;
}
