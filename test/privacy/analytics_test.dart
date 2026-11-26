import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/observability/analytics.dart';

const _stokvel = '22222222-2222-4222-8222-222222222222';
const _member = '11111111-1111-4111-8111-111111111111';

void main() {
  test('normal builds use no-op analytics', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appAnalyticsProvider), isA<NoopAnalytics>());
  });

  for (final event in AnalyticsEvent.values) {
    test('${event.name} contains only the declared ids', () {
      final recording = RecordingAnalytics();

      final container = ProviderContainer(
        overrides: [appAnalyticsProvider.overrideWithValue(recording)],
      );

      addTearDown(container.dispose);

      container
          .read(appAnalyticsProvider)
          .track(
            AnalyticsRecord(
              event: event,
              stokvelId: _stokvel,
              memberId: _member,
            ),
          );

      expect(recording.records, hasLength(1));
      expect(recording.records.single.toJson(), {
        'event': event.name,
        'stokvel_id': _stokvel,
        'member_id': _member,
      });

      expect(
        () => recording.records.single.fields['amount'] = '125050',
        throwsUnsupportedError,
      );
    });
  }

  for (final value in [
    'Thandi Nkosi',
    'thandi@example.invalid',
    '0821234567',
    'R\u00A01\u00A0250,50',
    'Thandi_proof_Nov.jpg',
    'eyJhbGciOiJIUzI1NiJ9.member.secret',
  ]) {
    test('rejects a personal value in an id field: $value', () {
      expect(
        () => AnalyticsRecord(
          event: AnalyticsEvent.stokvelOpened,
          stokvelId: value,
          memberId: _member,
        ),
        throwsFormatException,
      );

      expect(
        () => AnalyticsRecord(
          event: AnalyticsEvent.stokvelOpened,
          stokvelId: _stokvel,
          memberId: value,
        ),
        throwsFormatException,
      );
    });
  }
}
