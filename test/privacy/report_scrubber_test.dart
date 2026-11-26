import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/observability/error_reporter.dart';
import 'package:ronditrack/core/observability/report_scrubber.dart';
import 'package:ronditrack/core/observability/sentry_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _reference = '12100000-0000-4000-8000-000000000001';
const _name = 'Thandi Nkosi';
const _email = 'different@example.invalid';
const _token = 'eyJhbGciOiJIUzI1NiJ9.member.secret';
const _proof = 'Thandi_proof_Nov.jpg';

void main() {
  tearDown(() {
    Reporting.reporter = const NoopErrorReporter();
  });

  test('no personal value survives the serialised event', () {
    const leaks = [
      _name,
      _email,
      _token,
      _proof,
      '0821234567',
      'R 1 250,50',
      'R\u00A01\u00A0250,50',
    ];

    final leak = leaks.join(' ');
    final url = 'https://example.invalid/pay?q=Nkosi&token=$_token';

    final event = SentryEvent.fromJson({
      'event_id': '12100000000040008000000000000001',
      'timestamp': '2030-01-01T12:00:00Z',
      'release': leak,
      'message': {
        'formatted': leak,
        'params': [leak],
      },
      'exception': {
        'values': [
          {
            'type': leak,
            'value': leak,
            'module': leak,
            'stacktrace': {
              'frames': [
                {
                  'filename': 'package:ronditrack/core/network/client.dart',
                  'function': leak,
                  'abs_path': url,
                  'lineno': 42,
                  'vars': {'payment': leak},
                  'context_line': leak,
                  'pre_context': [leak],
                },
                {'filename': 'package:ronditrack/Nkosi.dart', 'lineno': 9},
              ],
              'registers': {'secret': leak},
            },
          },
        ],
      },
      'breadcrumbs': [
        {
          'timestamp': '2030-01-01T12:00:00Z',
          'message': '$url $leak',
          'category': leak,
          'data': {
            'url': url,
            'nested': {
              'values': [leak],
            },
          },
        },
      ],
      'tags': {
        'correlation_id': _reference,
        'failure_code': 'server_failure',
        'member': leak,
      },
      'user': {
        'id': leak,
        'username': _name,
        'email': _email,
        'data': {'private': leak},
      },
      'request': {
        'url': url,
        'method': 'POST',
        'data': leak,
        'headers': {'Authorization': 'Bearer $_token', 'Cookie': _token},
        'query_string': leak,
        'cookies': leak,
      },
      'contexts': {
        'business': {
          'nested': [leak],
        },
      },
      'extra': {'payment': leak},
      'transaction': leak,
      'fingerprint': [leak],
      'unknown_private_field': leak,
    });

    final clean = const ReportScrubber(environment: 'dev')
        .clean(event, memberNames: const [_name])!;

    final json = clean.toJson();
    final serialised = jsonEncode(json);

    for (final value in [...leaks, 'Nkosi', '?q=', 'Bearer']) {
      expect(
        serialised,
        isNot(contains(value)),
        reason: 'Leaked value: $value',
      );
    }

    expect(clean.tags, {
      'failure_code': 'server_failure',
      'correlation_id': _reference,
    });
    expect(clean.environment, 'dev');

    expect(clean.exceptions!.single.stackTrace!.frames, hasLength(1));
    expect(clean.exceptions!.single.stackTrace!.frames.single.lineNo, 42);

    for (final key in [
      'user',
      'request',
      'breadcrumbs',
      'extra',
      'transaction',
      'fingerprint',
      'unknown_private_field',
    ]) {
      expect(json.containsKey(key), isFalse, reason: 'Unexpected field: $key');
    }
  });

  test('keeps the SDK release and rejects unsafe references', () {
    const release = 'za.co.kgomotsonthuping.ronditrack.dev@0.1.0+1';

    final clean = const ReportScrubber(environment: 'dev').clean(
      SentryEvent(release: release, tags: const {'correlation_id': _proof}),
    )!;

    expect(clean.release, release);
    expect(
      const ReportScrubber(environment: 'dev')
          .clean(SentryEvent(release: 'ronditrack@0.1.0+1'))!
          .release,
      'ronditrack@0.1.0+1',
    );
    expect(clean.tags!.containsKey('correlation_id'), isFalse);
  });

  test('automatic captures also discard expected failures', () {
    expect(
      const ReportScrubber(environment: 'dev')
          .clean(SentryEvent(throwable: const OfflineFailure(isRead: true))),
      isNull,
    );
  });

  test('the reporter sink receives only a scrubbed event', () async {
    final sent = <SentryEvent>[];

    final reporter = SentryErrorReporter(
      scrubber: const ReportScrubber(environment: 'dev'),
      send: (event) async {
        sent.add(event);
      },
    );

    await reporter.report(
      ErrorReport(
        kind: ReportKind.serverFailure,
        correlationId: _reference,
        memberNames: const [_name],
        stackTrace: StackTrace.fromString(
          '#0 save (package:ronditrack/core/storage.dart:42:3)\n'
          '#1 $_name /users/$_email/$_proof $_token',
        ),
      ),
    );

    expect(sent, hasLength(1));
    expect(sent.single.tags!['correlation_id'], _reference);

    final encoded = jsonEncode(sent.single.toJson());

    for (final value in [_name, _email, _proof, _token]) {
      expect(encoded, isNot(contains(value)), reason: 'Leaked value: $value');
    }
  });

  test('reporting is off with no DSN and in tests', () async {
    var starts = 0;

    Future<void> initialize(
      void Function(SentryFlutterOptions) configure,
    ) async {
      starts++;
    }

    await startReporting(
      flavor: AppFlavor.dev,
      isTest: false,
      dsn: '',
      initialize: initialize,
    );

    await startReporting(
      flavor: AppFlavor.dev,
      isTest: true,
      dsn: 'https://public@example.invalid/1',
      initialize: initialize,
    );

    expect(starts, 0);
    expect(Reporting.reporter, isA<NoopErrorReporter>());
  });

  test('configuration disables automatic outbound channels', () async {
    const release = 'za.co.kgomotsonthuping.ronditrack.dev@0.1.0+1';

    final options = SentryFlutterOptions()..release = release;

    configureReporting(
      options,
      dsn: 'https://public@example.invalid/1',
      flavor: AppFlavor.dev,
    );

    expect(options.environment, 'dev');
    expect(options.release, release);
    expect(options.sendDefaultPii, isFalse);
    expect(options.enableAutoSessionTracking, isFalse);
    expect(options.enableNativeCrashHandling, isFalse);
    expect(options.enableAutoPerformanceTracing, isFalse);
    expect(options.tracesSampleRate, 0);
    expect(options.replay.sessionSampleRate, 0);
    expect(options.replay.onErrorSampleRate, 0);
    expect(options.attachScreenshot, isFalse);
    expect(options.attachViewHierarchy, isFalse);
    expect(options.enablePrintBreadcrumbs, isFalse);
    expect(options.sendClientReports, isFalse);

    final hint = Hint.withAttachment(
      SentryAttachment.fromIntList(utf8.encode(_name), _proof),
    );

    final event = await options.beforeSend!(
      SentryEvent(message: SentryMessage(_name)),
      hint,
    );

    expect(hint.attachments, isEmpty);
    expect(jsonEncode(event!.toJson()), isNot(contains(_name)));
    expect(
      options.beforeBreadcrumb!(Breadcrumb(message: _name), Hint()),
      isNull,
    );
  });
}
