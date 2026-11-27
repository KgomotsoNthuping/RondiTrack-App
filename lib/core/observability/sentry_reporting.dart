import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/observability/error_reporter.dart';
import 'package:ronditrack/core/observability/report_scrubber.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef EventSink = Future<void> Function(SentryEvent event);
typedef SentryInitializer = Future<void> Function(
  void Function(SentryFlutterOptions options) configure,
);

void configureReporting(
  SentryFlutterOptions options, {
  required String dsn,
  required AppFlavor flavor,
  String release = const String.fromEnvironment('SENTRY_RELEASE'),
  String dist = const String.fromEnvironment('SENTRY_DIST'),
}) {
  final scrubber = ReportScrubber(environment: flavor.name);

  options
    ..dsn = dsn
    ..environment = flavor.name
    ..sendDefaultPii = false
    ..debug = false
    ..sendClientReports = false
    ..enableAutoSessionTracking = false
    ..enableNativeCrashHandling = false
    ..anrEnabled = false
    ..enableAppHangTracking = false
    ..enableWatchdogTerminationTracking = false
    ..enableTombstone = false
    ..enableAutoPerformanceTracing = false
    ..enableUserInteractionTracing = false
    ..enableFramesTracking = false
    ..enableNativeTraceSync = false
    ..tracesSampleRate = 0
    ..enableAutoNativeBreadcrumbs = false
    ..enableAppLifecycleBreadcrumbs = false
    ..enableWindowMetricBreadcrumbs = false
    ..enableBrightnessChangeBreadcrumbs = false
    ..enableTextScaleChangeBreadcrumbs = false
    ..enableMemoryPressureBreadcrumbs = false
    ..enableUserInteractionBreadcrumbs = false
    ..enablePrintBreadcrumbs = false
    ..enableScopeSync = false
    ..enableNdkScopeSync = false
    ..attachScreenshot = false
    ..attachViewHierarchy = false
    ..attachThreads = false
    ..maxBreadcrumbs = 0
    ..captureFailedRequests = false
    ..captureNativeFailedRequests = false
    ..beforeBreadcrumb = (_, _) {
      return null;
    }
    ..beforeSendLog = (_, _) {
      return null;
    }
    ..beforeSendMetric = (_, _) {
      return null;
    }
    ..beforeSendTransaction = (_, _) {
      return null;
    }
    ..beforeSendFeedback = (_, _) {
      return null;
    }
    ..beforeSend = (event, hint) {
      hint.attachments.clear();
      hint.screenshot = null;
      hint.viewHierarchy = null;
      hint.response = null;
      hint.clear();
      return scrubber.clean(event);
    };

  if (release.isNotEmpty) {
    options.release = release;
  }
  if (dist.isNotEmpty) {
    options.dist = dist;
  }

  options.replay
    ..sessionSampleRate = 0
    ..onErrorSampleRate = 0;
}

Future<void> startReporting({
  required AppFlavor flavor,
  required bool isTest,
  String dsn = const String.fromEnvironment('SENTRY_DSN'),
  SentryInitializer initialize = _initialize,
  EventSink send = _send,
}) async {
  Reporting.reporter = const NoopErrorReporter();

  if (isTest || dsn.trim().isEmpty) {
    return;
  }

  await initialize((options) {
    configureReporting(options, dsn: dsn, flavor: flavor);
  });

  Reporting.reporter = SentryErrorReporter(
    scrubber: ReportScrubber(environment: flavor.name),
    send: send,
  );
}

Future<void> _initialize(void Function(SentryFlutterOptions) configure) =>
    SentryFlutter.init(configure);

Future<void> _send(SentryEvent event) async {
  await Sentry.captureEvent(event);
}

final class SentryErrorReporter implements ErrorReporter {
  const new({required this.scrubber, required this.send});

  final ReportScrubber scrubber;
  final EventSink send;

  @override
  Future<void> report(ErrorReport report) async {
    final matches = RegExp(
      r'(package:ronditrack/[A-Za-z0-9_/]+\.dart):(\d+):(\d+)',
    ).allMatches(report.stackTrace.toString());

    final event = SentryEvent(
      message: SentryMessage(report.kind.code),
      tags: {
        'failure_code': report.kind.code,
        if (report.correlationId != null)
          'correlation_id': report.correlationId!,
      },
      exceptions: [
        SentryException(
          type: 'ApplicationFailure',
          value: report.kind.code,
          stackTrace: SentryStackTrace(
            frames: [
              for (final match in matches)
                SentryStackFrame(
                  fileName: match[1],
                  lineNo: int.parse(match[2]!),
                  colNo: int.parse(match[3]!),
                  inApp: true,
                ),
            ].reversed.toList(),
          ),
        ),
      ],
    );

    final cleaned = scrubber.clean(event, memberNames: report.memberNames);
    if (cleaned != null) {
      await send(cleaned);
    }
  }
}
