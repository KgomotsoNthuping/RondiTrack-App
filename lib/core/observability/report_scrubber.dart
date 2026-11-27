import 'package:ronditrack/core/observability/error_reporter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

String? safeReportReference(String? value) {
  if (value == null || value.length > 128) {
    return null;
  }

  final valid = RegExp(
    r'^(?:[0-9a-f]{32}|'
    r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|'
    r'00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}|'
    r'[0-9a-v]{13}:[0-9a-f]{8}|'
    r'(?:corr|ref|request|trace)-[0-9a-f-]{3,80})$',
    caseSensitive: false,
  );

  return valid.hasMatch(value) ? value : null;
}

final class ReportScrubber {
  const new({required this.environment});

  final String environment;

  SentryEvent? clean(
    SentryEvent event, {
    Iterable<String> memberNames = const [],
  }) {
    final throwable = event.throwable;
    if (throwable is Object && reportKind(throwable) == null) {
      return null;
    }

    final names = memberNames
        .expand((name) => [name, ...name.split(RegExp(r'\s+'))])
        .where((name) => name.trim().length > 1)
        .map((name) => name.toLowerCase())
        .toSet();

    bool containsName(String value) => names.any(value.toLowerCase().contains);

    final code =
        ReportKind.values
            .map((kind) => kind.code)
            .where((code) => code == event.tags?['failure_code'])
            .firstOrNull ??
        ReportKind.unexpectedException.code;

    final reference = safeReportReference(event.tags?['correlation_id']);
    final frames = <SentryStackFrame>[];

    for (final exception in event.exceptions ?? <SentryException>[]) {
      for (final frame
          in exception.stackTrace?.frames ?? <SentryStackFrame>[]) {
        final file = frame.fileName;
        if (file == null ||
            containsName(file) ||
            !RegExp(r'^package:ronditrack/[A-Za-z0-9_/]+\.dart$')
                .hasMatch(file)) {
          continue;
        }

        frames.add(
          SentryStackFrame(
            fileName: file,
            lineNo: frame.lineNo,
            colNo: frame.colNo,
            inApp: true,
          ),
        );
      }
    }

    final release = event.release;
    final safeRelease =
        release != null &&
        release.trim() == release &&
        !containsName(release) &&
        RegExp(
          r'^(?:za\.co\.kgomotsonthuping\.|com\.example\.)?ronditrack'
          r'(?:\.(?:dev|staging))?@[0-9]+\.[0-9]+\.[0-9]+'
          r'(?:-[A-Za-z0-9.-]+)?(?:\+[0-9]+)?$',
        ).hasMatch(release);

    final dist = event.dist;
    final safeDist =
        safeRelease &&
        dist != null &&
        dist.trim() == dist &&
        RegExp(r'^[0-9]{1,10}$').hasMatch(dist) &&
        !containsName(dist);

    return SentryEvent(
      eventId: event.eventId,
      timestamp: event.timestamp,
      environment: environment,
      release: safeRelease ? release : null,
      dist: safeDist ? dist : null,
      platform: 'dart',
      level: SentryLevel.error,
      message: SentryMessage(code),
      tags: {
        'failure_code': code,
        if (reference != null && !containsName(reference))
          'correlation_id': reference,
      },
      exceptions: [
        SentryException(
          type: 'ApplicationFailure',
          value: code,
          stackTrace: frames.isEmpty ? null : SentryStackTrace(frames: frames),
        ),
      ],
    );
  }
}
