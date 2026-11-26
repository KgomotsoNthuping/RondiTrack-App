import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AnalyticsEvent {
  stokvelOpened('stokvel_opened'),
  contributionAttemptQueued('contribution_attempt_queued'),
  contributionConfirmed('contribution_confirmed');

  const new(this.name);

  final String name;
}

final class AnalyticsRecord {
  new({
    required this.event,
    required String stokvelId,
    required String memberId,
  }) : fields = Map.unmodifiable({
         'stokvel_id': _id(stokvelId),
         'member_id': _id(memberId),
       });

  final AnalyticsEvent event;
  final Map<String, String> fields;

  Map<String, Object> toJson() => {'event': event.name, ...fields};
}

String _id(String value) {
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-'
    r'[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value)) {
    throw const FormatException('Analytics requires an opaque UUID.');
  }

  return value.toLowerCase();
}

abstract interface class AppAnalytics {
  void track(AnalyticsRecord record);
}

final class NoopAnalytics implements AppAnalytics {
  const new();

  @override
  void track(AnalyticsRecord record) {}
}

final class RecordingAnalytics implements AppAnalytics {
  final records = <AnalyticsRecord>[];

  @override
  void track(AnalyticsRecord record) => records.add(record);
}

final appAnalyticsProvider = Provider<AppAnalytics>(
  (ref) => const NoopAnalytics(),
);
