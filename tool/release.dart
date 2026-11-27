import 'dart:convert';
import 'dart:io';

import 'release_policy.dart';

Future<void> main(List<String> arguments) async {
  try {
    await _release(arguments);
  } on ReleaseFailure catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on Object {
    stderr.writeln(
      'Release failed. Check the preceding command output.',
    );
    exitCode = 1;
  }
}

String requiredEnvironment(String name) {
  final value = Platform.environment[name]?.trim();

  if (value == null || value.isEmpty) {
    throw ReleaseFailure(
      'Set $name before releasing.',
    );
  }

  return value;
}

Future<String> command(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    environment: environment,
    runInShell: Platform.isWindows,
  );

  if (result.exitCode != 0) {
    throw ReleaseFailure(
      '$executable failed. Release refused.',
    );
  }

  return result.stdout.toString();
}

Future<void> liveCommand(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    environment: environment,
    runInShell: Platform.isWindows,
  );

  await Future.wait([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);

  if (await process.exitCode != 0) {
    throw ReleaseFailure(
      '$executable failed. Release refused.',
    );
  }
}

String jdkTool(String name) {
  final binary = Platform.isWindows
      ? '$name.exe'
      : name;

  final java = Platform.environment['JAVA_HOME'];

  return java == null || java.isEmpty
      ? binary
      : '$java/bin/$binary';
}

Map<String, Object?> readJson(String path) {
  final decoded = jsonDecode(
    File(path)
        .readAsStringSync()
        .replaceFirst('\uFEFF', ''),
  );

  if (decoded is! Map<String, dynamic>) {
    throw const ReleaseFailure(
      'Release configuration must be a JSON object.',
    );
  }

  return Map<String, Object?>.from(decoded);
}

void requireFile(String path) {
  if (!File(path).existsSync() ||
      File(path).lengthSync() == 0) {
    throw const ReleaseFailure(
      'A required release input or output file is missing.',
    );
  }
}

Map<String, Object?> runtimeConfig(
  String path,
  String flavor,
) {
  final data = readJson(path);

  const allowed = {
    'APP_FLAVOR',
    'API_BASE_URL',
    'REFRESH_COOKIE_NAME',
    'REFRESH_COOKIE_PATH',
    'SENTRY_DSN',
    'PROOF_UPLOAD_ENABLED',
    'PROOF_MAX_BYTES',
  };

  if (data.keys.any(
        (key) => !allowed.contains(key),
      ) ||
      data['APP_FLAVOR'] != flavor) {
    throw const ReleaseFailure(
      'Release configuration has unsupported keys '
      'or a wrong flavour.',
    );
  }

  final api = Uri.tryParse(
    data['API_BASE_URL']?.toString() ?? '',
  );

  if (api == null ||
      api.scheme != 'https' ||
      api.host.isEmpty ||
      api.userInfo.isNotEmpty ||
      api.hasQuery ||
      api.hasFragment ||
      const [
        'localhost',
        '127.0.0.1',
        '10.0.2.2',
      ].contains(api.host) ||
      api.host.endsWith('.invalid')) {
    throw const ReleaseFailure(
      'Use a real HTTPS API address reachable by the reviewer.',
    );
  }

  for (final key in [
    'REFRESH_COOKIE_NAME',
    'REFRESH_COOKIE_PATH',
    'SENTRY_DSN',
  ]) {
    if (data[key] is! String ||
        (data[key]! as String).trim().isEmpty) {
      throw ReleaseFailure(
        'Set $key in the release configuration.',
      );
    }
  }

  if (data['PROOF_UPLOAD_ENABLED'] == true &&
      (data['PROOF_MAX_BYTES'] is! int ||
          (data['PROOF_MAX_BYTES']! as int) <= 0)) {
    throw const ReleaseFailure(
      'Enabled proof uploads need the verified server file limit.',
    );
  }

  return data;
}

void validateFirebase(String path) {
  final data = readJson(path);

  const keys = {
    'FIREBASE_API_KEY',
    'FIREBASE_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_PROJECT_ID',
  };

  if (data.length != keys.length ||
      !data.keys.toSet().containsAll(keys) ||
      data.values.any(
        (value) =>
            value is! String ||
            value.trim().isEmpty,
      )) {
    throw const ReleaseFailure(
      'Release Firebase config needs exactly '
      'the four client settings.',
    );
  }
}

Future<void> _release(
  List<String> arguments,
) async {
  final privatePath =
      Platform.environment['ANDROID_KEY_PROPERTIES'];

  if (privatePath != null &&
      !File(privatePath).isAbsolute) {
    throw const ReleaseFailure(
      'ANDROID_KEY_PROPERTIES must be an absolute path.',
    );
  }

  final signing = readSigningProperties(
    privatePath ?? 'android/key.properties',
  );

  requiredEnvironment('ANDROID_STORE_PASSWORD');
  requiredEnvironment('ANDROID_KEY_PASSWORD');

  final expected = normalizeFingerprint(
    requiredEnvironment('ANDROID_UPLOAD_SHA256'),
  );

  final root =
      Directory.current.resolveSymbolicLinksSync();

  final keystore = File(signing['storeFile']!);

  if (!keystore.isAbsolute ||
      !keystore.existsSync()) {
    throw const ReleaseFailure(
      'The upload keystore must exist at an absolute private path.',
    );
  }

  final resolvedStore =
      keystore.resolveSymbolicLinksSync();

  final compareRoot = Platform.isWindows
      ? root.toLowerCase()
      : root;

  final compareStore = Platform.isWindows
      ? resolvedStore.toLowerCase()
      : resolvedStore;

  if (compareStore.startsWith(
    '$compareRoot${Platform.pathSeparator}',
  )) {
    throw const ReleaseFailure(
      'Keep the upload keystore outside the repository.',
    );
  }

  final options = <String, String>{};

  for (final argument in arguments) {
    final split = argument.indexOf('=');

    if (!argument.startsWith('--') || split < 3) {
      throw const ReleaseFailure(
        'Use --tag=, --run-number= and --run-attempt= options.',
      );
    }

    final name = argument.substring(2, split);

    if (!const [
          'tag',
          'run-number',
          'run-attempt',
        ].contains(name) ||
        options.containsKey(name)) {
      throw const ReleaseFailure(
        'Unknown or duplicate release option.',
      );
    }

    options[name] = argument.substring(split + 1);
  }

  final tag =
      options['tag'] ??
      requiredEnvironment('GITHUB_REF_NAME');

  final run =
      int.tryParse(
        options['run-number'] ??
            requiredEnvironment('GITHUB_RUN_NUMBER'),
      ) ??
      0;

  final attempt =
      int.tryParse(
        options['run-attempt'] ??
            Platform.environment['GITHUB_RUN_ATTEMPT'] ??
            '1',
      ) ??
      0;

  final identity = ReleaseIdentity.create(
    tag,
    run,
    attempt,
  );

  final head = (
    await command('git', ['rev-parse', 'HEAD'])
  ).trim();

  final tagged = (
    await command(
      'git',
      ['rev-parse', '$tag^{commit}'],
    )
  ).trim();

  final status = await command(
    'git',
    ['status', '--porcelain'],
  );

  if (head != tagged || status.trim().isNotEmpty) {
    throw const ReleaseFailure(
      'Release the exact tagged commit '
      'from a clean working tree.',
    );
  }

  final history = await command('git', [
    'log',
    '--all',
    '--format=%H',
    '--',
    '*.jks',
    '*.keystore',
    '*key.properties',
    '*service-account*',
    '*service_account*',
    '*firebase-adminsdk*',
  ]);

  if (history.trim().isNotEmpty) {
    throw const ReleaseFailure(
      'Private signing/service-account filenames '
      'exist in Git history.',
    );
  }

  final sdk =
      jsonDecode(
            await command(
              'flutter',
              ['--version', '--machine'],
            ),
          )
          as Map<String, dynamic>;

  if (sdk['frameworkVersion'] != '3.47.9' ||
      (sdk['dartSdkVersion'] as String)
              .split(' ')
              .first !=
          '3.13.7') {
    throw const ReleaseFailure(
      'Use this project’s Flutter 3.47.9 and Dart 3.13.7.',
    );
  }

  final keyOutput = await command(
    jdkTool('keytool'),
    [
      '-J-Duser.language=en',
      '-list',
      '-v',
      '-keystore',
      resolvedStore,
      '-alias',
      signing['keyAlias']!,
      '-storepass:env',
      'ANDROID_STORE_PASSWORD',
    ],
  );

  if (keyOutput.contains('CN=Android Debug') ||
      signing['keyAlias']!.toLowerCase() ==
          'androiddebugkey') {
    throw const ReleaseFailure(
      'Debug certificates cannot sign a release.',
    );
  }

  verifyFingerprint(
    certificateFingerprint(keyOutput),
    expected,
  );

  final android =
      Platform.environment['ANDROID_HOME'] ??
      requiredEnvironment('ANDROID_SDK_ROOT');

  final buildTools =
      Directory('$android/build-tools')
          .listSync()
          .whereType<Directory>()
          .where(
            (directory) => RegExp(
              r'[0-9]+\.[0-9]+\.[0-9]+$',
            ).hasMatch(directory.path),
          )
          .toList()
        ..sort((a, b) {
          List<int> parts(Directory directory) => directory
              .uri
              .pathSegments
              .where((segment) => segment.isNotEmpty)
              .last
              .split('.')
              .map(int.parse)
              .toList();

          final first = parts(a);
          final second = parts(b);

          for (var index = 0; index < 3; index++) {
            final order = second[index].compareTo(
              first[index],
            );

            if (order != 0) {
              return order;
            }
          }

          return 0;
        });

  if (buildTools.isEmpty) {
    throw const ReleaseFailure(
      'Install Android build-tools 37.0.0.',
    );
  }

  String androidTool(String name) {
    final extension = Platform.isWindows
        ? (name == 'apksigner' ? '.bat' : '.exe')
        : '';

    return '${buildTools.first.path}/$name$extension';
  }

  final output = Directory(
    'release-output/${identity.tag}-${identity.buildNumber}',
  );

  if (output.existsSync()) {
    throw const ReleaseFailure(
      'This release output already exists. '
      'Use the next CI attempt.',
    );
  }

  final temporary = Directory.systemTemp.createTempSync(
    'ronditrack-release-',
  );

  final releases = <Map<String, Object?>>[];

  try {
    for (final flavor in ['staging', 'prod']) {
      final prefix = flavor.toUpperCase();

      final config = runtimeConfig(
        requiredEnvironment('RT_${prefix}_CONFIG'),
        flavor,
      );

      final firebase = File(
        requiredEnvironment(
          'RT_${prefix}_FIREBASE_CONFIG',
        ),
      ).absolute.path;

      validateFirebase(firebase);

      requireFile(
        'assets/branding/$flavor/icon.png',
      );
      requireFile(
        'android/app/src/$flavor/res/values/styles.xml',
      );
      requireFile(
        'android/app/src/$flavor/res/'
        'mipmap-anydpi-v26/ic_launcher.xml',
      );

      final directory = Directory(
        '${output.path}/$flavor',
      );

      final symbols = Directory(
        '${directory.path}/symbols',
      )..createSync(recursive: true);

      final map = File(
        '${symbols.path}/obfuscation-map.json',
      );

      final runtime = File(
        '${temporary.path}/$flavor.json',
      );

      runtime.writeAsStringSync(
        jsonEncode({
          ...config,
          'SENTRY_RELEASE': identity.release(flavor),
          'SENTRY_DIST':
              identity.buildNumber.toString(),
        }),
      );

      stdout.writeln(
        'Building signed $flavor '
        '${identity.version} (${identity.buildNumber})…',
      );

      await liveCommand('flutter', [
        'build',
        flavor == 'staging' ? 'apk' : 'appbundle',
        '--release',
        '--no-pub',
        '--flavor=$flavor',
        '--target-platform=android-arm64',
        '--build-name=${identity.version}',
        '--build-number=${identity.buildNumber}',
        '--obfuscate',
        '--split-debug-info=${symbols.absolute.path}',
        '--extra-gen-snapshot-options='
            '--save-obfuscation-map=${map.absolute.path}',
        '--dart-define-from-file=${runtime.path}',
        '--dart-define-from-file=$firebase',
      ]);

      final source = flavor == 'staging'
          ? 'build/app/outputs/flutter-apk/'
                'app-staging-release.apk'
          : 'build/app/outputs/bundle/prodRelease/'
                'app-prod-release.aab';

      requireFile(source);
      requireFile(map.path);
      requireFile(
        '${symbols.path}/app.android-arm64.symbols',
      );

      final mapping =
          'build/app/outputs/mapping/'
          '${flavor}Release/mapping.txt';

      requireFile(mapping);

      final String fingerprint;

      if (flavor == 'staging') {
        final certificate = await command(
          androidTool('apksigner'),
          [
            'verify',
            '--verbose',
            '--print-certs',
            source,
          ],
        );

        fingerprint = certificateFingerprint(
          certificate,
          apk: true,
        );

        final badging = await command(
          androidTool('aapt2'),
          ['dump', 'badging', source],
        );

        final packageLines = badging
            .split('\n')
            .where(
              (line) => line.startsWith('package:'),
            )
            .toList();

        if (packageLines.length != 1) {
          throw const ReleaseFailure(
            'Could not read the APK package metadata.',
          );
        }

        for (final item in [
          "name='${identity.appId(flavor)}'",
          "versionCode='${identity.buildNumber}'",
          "versionName='${identity.version}'",
        ]) {
          if (!packageLines.single.contains(item)) {
            throw const ReleaseFailure(
              'The APK identity/version '
              'does not match the release.',
            );
          }
        }
      } else {
        final verification = await command(
          jdkTool('jarsigner'),
          [
            '-J-Duser.language=en',
            '-verify',
            source,
          ],
        );

        if (!verification.contains('jar verified.') ||
            verification.contains('unsigned entries')) {
          throw const ReleaseFailure(
            'The app bundle signature was not verified.',
          );
        }

        fingerprint = certificateFingerprint(
          await command(
            jdkTool('keytool'),
            [
              '-J-Duser.language=en',
              '-printcert',
              '-jarfile',
              source,
            ],
          ),
        );
      }

      verifyFingerprint(
        fingerprint,
        expected,
      );

      final extension = flavor == 'staging'
          ? 'apk'
          : 'aab';

      final artifact =
          '${directory.path}/ronditrack-$flavor-'
          '${identity.version}+'
          '${identity.buildNumber}.$extension';

      await File(source).copy(artifact);

      await File(mapping).copy(
        '${symbols.path}/r8-mapping.txt',
      );

      releases.add({
        'flavor': flavor,
        'version': identity.version,
        'buildNumber': identity.buildNumber,
        'release': identity.release(flavor),
        'artifact': artifact,
        'symbols': symbols.path,
        'dartMap': map.path,
        'certificateSha256': fingerprint,
      });

      stdout.writeln(
        'Verified $flavor upload-key certificate.',
      );
    }

    final manifest = {
      'tag': identity.tag,
      'commit': head,
      'verified': true,
      'releases': releases,
    };

    File(
      'release-output/manifest.json',
    ).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(
        manifest,
      ),
    );

    stdout.writeln(
      'Verified release artifacts: ${output.path}',
    );
  } finally {
    temporary.deleteSync(recursive: true);
  }
}