import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/offline/outbox_policy.dart';

void main() {
  final policy = OutboxPolicy(
    maximumAge: const Duration(hours: 24),
    serverRetention: const Duration(hours: 48),
  );

  final createdAt = DateTime.utc(2026, 11, 1, 10);

  group('Outbox policy', () {
    test('a new payment is within the replay window', () {
      expect(
        policy.assess(createdAtUtc: createdAt, nowUtc: createdAt),
        OutboxAge.sendable,
      );
    });

    test('a payment just before expiry remains sendable', () {
      expect(
        policy.assess(
          createdAtUtc: createdAt,
          nowUtc: createdAt
              .add(const Duration(hours: 24))
              .subtract(const Duration(seconds: 1)),
        ),
        OutboxAge.sendable,
      );
    });

    test('a payment expires at the exact maximum age', () {
      expect(
        policy.assess(
          createdAtUtc: createdAt,
          nowUtc: createdAt.add(const Duration(hours: 24)),
        ),
        OutboxAge.expired,
      );
    });

    test('an older payment must never be replayed', () {
      expect(
        policy.assess(
          createdAtUtc: createdAt,
          nowUtc: createdAt.add(const Duration(days: 3)),
        ),
        OutboxAge.expired,
      );
    });

    test('a backwards clock blocks replay', () {
      expect(
        policy.assess(
          createdAtUtc: createdAt,
          nowUtc: createdAt.subtract(const Duration(minutes: 1)),
        ),
        OutboxAge.clockMismatch,
      );
    });

    for (final maximumAge in const [
      Duration.zero,
      Duration(hours: -1),
      Duration(hours: 48),
      Duration(hours: 49),
    ]) {
      test('rejects unsafe maximum age $maximumAge', () {
        expect(
          () => OutboxPolicy(
            maximumAge: maximumAge,
            serverRetention: const Duration(hours: 48),
          ),
          throwsArgumentError,
        );
      });
    }

    test('server retention must be positive', () {
      expect(
        () => OutboxPolicy(
          maximumAge: const Duration(hours: 24),
          serverRetention: Duration.zero,
        ),
        throwsArgumentError,
      );
    });
  });
}
