import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/observability/report_scrubber.dart';
import 'package:ronditrack/core/observability/sentry_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  const release =
      'za.co.kgomotsonthuping.ronditrack.staging'
      '@1.4.0+3702';

  test(
    'reporting uses the same release and dist as the upload step',
    () {
      final options = SentryFlutterOptions();

      configureReporting(
        options,
        dsn: 'https://public@example.invalid/1',
        flavor: AppFlavor.staging,
        release: release,
        dist: '3702',
      );

      expect(options.release, release);
      expect(options.dist, '3702');
      expect(options.sendDefaultPii, isFalse);
      expect(options.attachScreenshot, isFalse);
      expect(
        options.enableNativeCrashHandling,
        isFalse,
      );
    },
  );

  test(
    'privacy scrubber preserves only valid release/build metadata',
    () {
      const scrubber = ReportScrubber(
        environment: 'staging',
      );

      final event = scrubber.clean(
        SentryEvent(
          release: release,
          dist: '3702',
          tags: const {
            'failure_code': 'server_failure',
          },
        ),
      )!;

      expect(event.release, release);
      expect(event.dist, '3702');

      final unsafe = scrubber.clean(
        SentryEvent(
          release: release,
          dist: 'member@example.invalid',
        ),
      )!;

      expect(unsafe.dist, isNull);

      expect(
        jsonEncode(unsafe.toJson()),
        isNot(
          contains('member@example.invalid'),
        ),
      );

      final newline = scrubber.clean(
        SentryEvent(
          release: release,
          dist: '3702\n',
        ),
      )!;

      expect(newline.dist, isNull);
    },
  );
}