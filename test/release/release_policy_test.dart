import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_policy.dart';

void main() {
  test(
    'name comes from the tag and number from the CI run/attempt',
    () {
      final release = ReleaseIdentity.create(
        'v1.4.0',
        37,
        2,
      );

      expect(release.version, '1.4.0');
      expect(release.buildNumber, 3702);

      expect(
        release.release('staging'),
        'za.co.kgomotsonthuping.ronditrack.staging'
        '@1.4.0+3702',
      );

      expect(
        ReleaseIdentity.create(
          'v1.4.0',
          37,
          3,
        ).buildNumber,
        greaterThan(release.buildNumber),
      );
    },
  );

  test(
    'rejects malformed tags and invalid Android build numbers',
    () {
      for (final tag in [
        '1.4.0',
        'v01.4.0',
        'v1.4',
        'v1.4.0-beta',
        'v1.4.0\n',
      ]) {
        expect(
          () => ReleaseIdentity.create(tag, 1, 1),
          throwsA(isA<ReleaseFailure>()),
        );
      }

      for (final values in [
        (0, 1),
        (1, 0),
        (1, 100),
        (21000000, 1),
      ]) {
        expect(
          () => ReleaseIdentity.create(
            'v1.4.0',
            values.$1,
            values.$2,
          ),
          throwsA(isA<ReleaseFailure>()),
        );
      }
    },
  );

  test('a different certificate is refused', () {
    final upload = List.filled(64, 'A').join();
    final debug = List.filled(64, 'B').join();

    expect(
      () => verifyFingerprint(debug, upload),
      throwsA(isA<ReleaseFailure>()),
    );

    expect(
      () => verifyFingerprint(
        upload.toLowerCase(),
        upload,
      ),
      returnsNormally,
    );
  });

  test(
    'certificate parsers require one complete SHA-256 value',
    () {
      final digest = List.filled(32, 'AB').join();
      final colon = List.filled(32, 'AB').join(':');

      expect(
        certificateFingerprint(
          'SHA256: $colon',
        ),
        digest,
      );

      expect(
        certificateFingerprint(
          'Signer #1 certificate SHA-256 digest: '
          '${digest.toLowerCase()}',
          apk: true,
        ),
        digest,
      );

      expect(
        () => certificateFingerprint(
          'not signed',
        ),
        throwsA(isA<ReleaseFailure>()),
      );

      expect(
        () => certificateFingerprint(
          'SHA256: AB:CD',
        ),
        throwsA(isA<ReleaseFailure>()),
      );
    },
  );

  test(
    'missing signing file fails before a build can start',
    () {
      final directory =
          Directory.systemTemp.createTempSync(
            'ronditrack-policy-',
          );

      try {
        expect(
          () => readSigningProperties(
            '${directory.path}/missing-key.properties',
          ),
          throwsA(
            isA<ReleaseFailure>().having(
              (error) => error.message,
              'message',
              contains('Missing private'),
            ),
          ),
        );
      } finally {
        directory.deleteSync(recursive: true);
      }
    },
  );
}