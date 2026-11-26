import 'dart:async';

import 'package:ronditrack/core/errors/failure.dart';

enum ReportKind {
  serverFailure('server_failure'),
  contractFailure('contract_failure'),
  unexpectedException('unexpected_exception');

  const new(this.code);

  final String code;
}

final class ErrorReport {
  new({
    required this.kind,
    required this.stackTrace,
    this.correlationId,
    Iterable<String> memberNames = const [],
  }) : memberNames = List.unmodifiable(memberNames);

  final ReportKind kind;
  final StackTrace stackTrace;
  final String? correlationId;
  final List<String> memberNames;
}

abstract interface class ErrorReporter {
  Future<void> report(ErrorReport report);
}

final class NoopErrorReporter implements ErrorReporter {
  const new();

  @override
  Future<void> report(ErrorReport report) async {}
}

final class RecordingErrorReporter implements ErrorReporter {
  final reports = <ErrorReport>[];

  @override
  Future<void> report(ErrorReport report) async {
    reports.add(report);
  }
}

ReportKind? reportKind(Object error) => switch (error) {
  ServerFailure() => ReportKind.serverFailure,
  Failure() || TimeoutException() => null,
  FormatException() => ReportKind.contractFailure,
  _ => ReportKind.unexpectedException,
};

abstract final class Reporting {
  static ErrorReporter _reporter = const NoopErrorReporter();
  static Expando<DateTime> _seen = Expando<DateTime>();
  static DateTime Function() clock = DateTime.now;

  static ErrorReporter get reporter => _reporter;

  static set reporter(ErrorReporter value) {
    _reporter = value;
    _seen = Expando<DateTime>();
  }

  static void capture(
    Object error,
    StackTrace stack, {
    Iterable<String> memberNames = const [],
  }) {
    final kind = reportKind(error);

    if (kind == null || _reporter is NoopErrorReporter) {
      return;
    }

    if (error is Exception || error is Error) {
      final now = clock().toUtc();
      final previous = _seen[error];

      if (previous != null &&
          now.isBefore(previous.add(const Duration(seconds: 1)))) {
        return;
      }

      _seen[error] = now;
    }

    final report = ErrorReport(
      kind: kind,
      stackTrace: stack,
      correlationId: error is Failure ? error.correlationId : null,
      memberNames: memberNames,
    );

    unawaited(
      Future<void>.sync(() => _reporter.report(report))
          .catchError((Object _, StackTrace _) {}),
    );
  }
}
