import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';

void main() {
  test('failures provide their own messages', () {
    final cases = <(Failure, String)>[
      (
        ValidationFailure(errors: const {}),
        'Check the highlighted fields.',
      ),
      (const UnauthorizedFailure(), 'Please sign in again.'),
      (
        const ForbiddenFailure(),
        'You do not have permission to do that.',
      ),
      (const NotFoundFailure(), 'Not found'),
      (
        const ConflictFailure(),
        'This information changed elsewhere. Reload and try again.',
      ),
      (
        const RuleFailure(detail: 'The cycle is already closed.'),
        'The cycle is already closed.',
      ),
      (
        const RateLimitedFailure(retryAfterSeconds: 17),
        'Too many attempts. Try again in 17 seconds.',
      ),
      (
        const ServerFailure(correlationId: 'request-123'),
        'Sorry, something went wrong on our side.',
      ),
      (
        const OfflineFailure(isRead: true),
        'You’re offline, or we couldn’t reach the server.',
      ),
    ];

    for (final (failure, expected) in cases) {
      expect(failure.message, expected);
      expect(failure.toString(), expected);
    }
  });

  test('validation preserves field errors without exposing mutable data', () {
    final messages = ['Enter an amount.'];
    final fields = {'amount': messages};

    final failure = ValidationFailure(
      errors: fields,
      detail: 'Check your contribution.',
      correlationId: 'validation-123',
    );

    messages.add('Changed after construction.');
    fields.clear();

    expect(failure.errors, {
      'amount': ['Enter an amount.'],
    });
    expect(failure.message, 'Check your contribution.');
    expect(failure.correlationId, 'validation-123');

    expect(
      () => failure.errors['amount']!.add('Another error.'),
      throwsUnsupportedError,
    );
    expect(
      () => failure.errors['other'] = ['An error.'],
      throwsUnsupportedError,
    );
  });

  test('only an offline read is eligible for automatic retry', () {
    final cases = <(Failure, bool)>[
      (ValidationFailure(errors: const {}), false),
      (const UnauthorizedFailure(), false),
      (const ForbiddenFailure(), false),
      (const NotFoundFailure(), false),
      (const ConflictFailure(), false),
      (const RuleFailure(), false),
      (const RateLimitedFailure(retryAfterSeconds: 30), false),
      (const ServerFailure(), false),
      (const OfflineFailure(isRead: false), false),
      (const OfflineFailure(isRead: true), true),
    ];

    for (final (failure, expected) in cases) {
      expect(
        failure.canRetry,
        expected,
        reason: failure.runtimeType.toString(),
      );
    }
  });

  test('a missing rate-limit header does not invent a wait', () {
    const failure = RateLimitedFailure();

    expect(failure.retryAfterSeconds, isNull);
    expect(failure.message, 'Too many attempts. Try again later.');
  });

  test('Result forces the caller to handle success and failure', () {
    const results = <Result<int>>[
      Ok(7),
      Err(NotFoundFailure(correlationId: 'missing-123')),
    ];

    final messages = [
      for (final result in results)
        switch (result) {
          Ok<int>(:final value) => value.toString(),
          Err<int>(:final failure) => failure.message,
        },
    ];

    expect(messages, ['7', 'Not found']);

    final failed = results.last as Err<int>;
    expect(failed.failure.correlationId, 'missing-123');
  });
}