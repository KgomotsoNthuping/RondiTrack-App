import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/failure_mapper.dart';
import 'package:ronditrack/core/observability/error_reporter.dart';

void main() {
  late RecordingErrorReporter recording;

  setUp(() {
    recording = RecordingErrorReporter();
    Reporting.reporter = recording;
    Reporting.clock = () => DateTime.utc(2030);
  });

  tearDown(() {
    Reporting.reporter = const NoopErrorReporter();
    Reporting.clock = DateTime.now;
  });

  test('expected operational failures are not reported', () async {
    final failures = <Object>[
      const OfflineFailure(isRead: true),
      const UnauthorizedFailure(),
      const ForbiddenFailure(),
      const NotFoundFailure(),
      const ConflictFailure(),
      const RuleFailure(),
      const RateLimitedFailure(),
      ValidationFailure(errors: const {}),
      TimeoutException('No answer'),
    ];

    for (final failure in failures) {
      Reporting.capture(failure, StackTrace.current);
    }

    await Future<void>.value();
    expect(recording.reports, isEmpty);
  });

  test('a mapped server failure is reported once with its reference', () async {
    const reference = '12100000-0000-4000-8000-000000000001';

    final options = RequestOptions(path: '/api/v1/me/home');

    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: options,
        statusCode: 500,
        data: const {
          'detail': 'Thandi Nkosi paid R 1 250,50',
          'correlationId': reference,
        },
      ),
    );

    final failure = mapFailure(error, isRead: true);

    Reporting.capture(failure, StackTrace.current);

    await Future<void>.value();

    expect(recording.reports, hasLength(1));
    expect(recording.reports.single.kind, ReportKind.serverFailure);
    expect(recording.reports.single.correlationId, reference);
  });

  test('deduplication does not suppress a later occurrence forever', () async {
    var now = DateTime.utc(2030);
    Reporting.clock = () => now;

    const failure = ServerFailure();

    Reporting.capture(failure, StackTrace.current);
    Reporting.capture(failure, StackTrace.current);

    await Future<void>.value();
    expect(recording.reports, hasLength(1));

    now = now.add(const Duration(seconds: 2));

    Reporting.capture(failure, StackTrace.current);

    await Future<void>.value();
    expect(recording.reports, hasLength(2));
  });

  test('contract and unexpected errors reach the interface', () async {
    Reporting.capture(
      const FormatException('Invalid private response'),
      StackTrace.current,
    );

    Reporting.capture(StateError('Private storage detail'), StackTrace.current);

    await Future<void>.value();

    expect(recording.reports.map((report) => report.kind), [
      ReportKind.contractFailure,
      ReportKind.unexpectedException,
    ]);
  });
}
