import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/failure_mapper.dart';

void main() {
  DioException responseError(
    int status, {
    Object? data,
    Map<String, List<String>> headers = const {},
  }) {
    final request = RequestOptions(path: '/test');
    return DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: request,
        statusCode: status,
        data: data,
        headers: Headers.fromMap(headers),
      ),
    );
  }

  for (final (status, type) in <(int, Type)>[
    (400, ValidationFailure),
    (401, UnauthorizedFailure),
    (403, ForbiddenFailure),
    (404, NotFoundFailure),
    (409, ConflictFailure),
    (422, RuleFailure),
    (429, RateLimitedFailure),
    (500, ServerFailure),
    (503, ServerFailure),
    (418, ServerFailure),
  ]) {
    test('$status maps safely with or without ProblemDetails', () {
      for (final data in <Object?>[
        null,
        const <String, Object?>{},
        '<html>Proxy unavailable</html>',
        {'detail': 'Check this action.', 'correlationId': 'trace-12.1'},
      ]) {
        final failure = mapFailure(
          responseError(status, data: data),
          isRead: false,
        );

        expect(failure.runtimeType, type);
        expect(failure.canRetry, isFalse);
        expect(failure.message, isNotEmpty);
      }
    });
  }

  test('JSON ProblemDetails keeps valid field messages', () {
    final failure = mapFailure(
      responseError(
        400,
        data: jsonEncode({
          'detail': 'Check the payment.',
          'correlationId': 'trace-12.1',
          'errors': {
            'amountInCents': ['Must be positive.', '', 42],
            'cycleId': 'Invalid shape',
          },
        }),
      ),
      isRead: false,
    ) as ValidationFailure;

    expect(failure.detail, 'Check the payment.');
    expect(failure.correlationId, 'trace-12.1');
    expect(failure.errors, {
      'amountInCents': ['Must be positive.'],
    });
    expect(() => failure.errors['extra'] = ['Changed'], throwsUnsupportedError);
    expect(
      () => failure.errors['amountInCents']!.add('Changed'),
      throwsUnsupportedError,
    );
  });

  test('invalid body correlation falls back to the safe header', () {
    final failure = mapFailure(
      responseError(
        500,
        data: {'correlationId': 'name@example.invalid private data'},
        headers: {
          'x-correlation-id': ['safe-trace:12.1'],
        },
      ),
      isRead: true,
    );

    expect(failure.correlationId, 'safe-trace:12.1');
  });

  test('unsafe correlation and proxy HTML are discarded', () {
    final failure = mapFailure(
      responseError(
        503,
        data: '<html>private proxy detail</html>',
        headers: {
          'x-correlation-id': ['private name'],
        },
      ),
      isRead: true,
    );

    expect(failure.correlationId, isNull);
    expect(failure.detail, isNull);
    expect(failure.message, isNot(contains('private')));
  });

  for (final header in ['20', '0', '-1', 'later']) {
    test('429 Retry-After seconds: $header', () {
      final failure = mapFailure(
        responseError(
          429,
          headers: {
            'retry-after': [header],
          },
        ),
        isRead: false,
      ) as RateLimitedFailure;

      expect(failure.retryAfterSeconds, switch (header) {
        '20' => 20,
        '0' => 0,
        _ => null,
      });
    });
  }

  for (final method in ['GET', 'HEAD', 'POST', 'PUT', 'DELETE']) {
    test('no-answer $method only offers a safe read retry', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final failure = mapFailure(
          DioException(
            requestOptions: RequestOptions(path: '/test', method: method),
            type: type,
          ),
          isRead: true,
        );

        expect(failure, isA<OfflineFailure>());
        expect(failure.canRetry, method == 'GET' || method == 'HEAD');
      }
    });
  }

  test('cancellation and write timeouts never offer read retry', () {
    expect(
      mapFailure(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.cancel,
        ),
        isRead: true,
      ).canRetry,
      isFalse,
    );
    expect(
      mapFailure(TimeoutException('No answer'), isRead: false).canRetry,
      isFalse,
    );
    expect(
      mapFailure(const OfflineFailure(isRead: true), isRead: false).canRetry,
      isFalse,
    );
  });

  test('parallel reads prioritise not found inside .wait', () async {
    Object? caught;

    try {
      await (
        Future<int>.error(responseError(503)),
        Future<int>.error(responseError(404)),
      ).wait;
    } on Object catch (error) {
      caught = error;
    }

    expect(caught, isNotNull);
    expect(mapFailure(caught!, isRead: true), isA<NotFoundFailure>());
  });
}
