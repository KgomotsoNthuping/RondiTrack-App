import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/app/provider_retry.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/api_result.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/network/data/failure_mapper.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/demo_session.dart';

void main() {
  group('Failure mapping', () {
    for (final (status, expectedType) in <(int, Type)>[
      (400, ValidationFailure),
      (401, UnauthorizedFailure),
      (403, ForbiddenFailure),
      (404, NotFoundFailure),
      (409, ConflictFailure),
      (422, RuleFailure),
      (429, RateLimitedFailure),
      (500, ServerFailure),
      (502, ServerFailure),
    ]) {
      test('maps HTTP $status to $expectedType', () {
        final failure = mapFailure(_httpError(status), isRead: true);

        expect(failure.runtimeType, expectedType);
        expect(failure.canRetry, isFalse);
      });
    }

    test('preserves validation fields and the error reference', () {
      final failure = mapFailure(
        _httpError(
          400,
          data: jsonEncode({
            'detail': 'Check the contribution.',
            'correlationId': 'trace-validation-03',
            'errors': {
              'amount': ['Enter an amount greater than zero.'],
            },
          }),
        ),
        isRead: false,
      );

      expect(
        failure,
        isA<ValidationFailure>()
            .having((value) => value.errors['amount'], 'amount errors', [
              'Enter an amount greater than zero.',
            ])
            .having(
              (value) => value.correlationId,
              'reference',
              'trace-validation-03',
            ),
      );
    });

    test('uses the HTTP status when the body status disagrees', () {
      final failure = mapFailure(
        _httpError(404, data: {'status': 500}),
        isRead: true,
      );

      expect(failure, isA<NotFoundFailure>());
    });

    test('handles HTML proxy errors and preserves a header reference', () {
      final failure = mapFailure(
        _httpError(
          502,
          data: '<html>Internal proxy information</html>',
          headers: {
            'x-correlation-id': ['proxy-reference-03'],
          },
        ),
        isRead: true,
      );

      expect(
        failure,
        isA<ServerFailure>().having(
          (value) => value.correlationId,
          'reference',
          'proxy-reference-03',
        ),
      );

      expect(failure.message, isNot(contains('Internal proxy')));
    });

    test('keeps internal server details out of the message', () {
      final failure = mapFailure(
        _httpError(
          500,
          data: {
            'detail': 'Internal database connection information',
            'correlationId': 'server-reference-03',
          },
        ),
        isRead: true,
      );

      expect(failure, isA<ServerFailure>());
      expect(failure.message, isNot(contains('database')));
      expect(failure.correlationId, 'server-reference-03');
    });

    test('reads Retry-After seconds without inventing a delay', () {
      final failure = mapFailure(
        _httpError(
          429,
          headers: {
            'retry-after': ['17'],
          },
        ),
        isRead: false,
      );

      expect(
        failure,
        isA<RateLimitedFailure>().having(
          (value) => value.retryAfterSeconds,
          'retry delay',
          17,
        ),
      );

      expect(
        mapFailure(_httpError(429), isRead: true),
        isA<RateLimitedFailure>().having(
          (value) => value.retryAfterSeconds,
          'missing retry delay',
          isNull,
        ),
      );
    });

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('$type retries reads and leaves writes to the user', () {
        final read = mapFailure(
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/me/home'),
            type: type,
          ),
          isRead: true,
        );

        final write = mapFailure(
          DioException(
            requestOptions: RequestOptions(
              path: '/api/v1/contributions',
              method: 'POST',
            ),
            type: type,
          ),
          isRead: true,
        );

        expect(read, isA<OfflineFailure>());
        expect(read.canRetry, isTrue);
        expect(write.canRetry, isFalse);
      });
    }

    test('parsing and certificate errors do not trigger retries', () {
      expect(
        mapFailure(const FormatException('Invalid response'), isRead: true),
        isA<ServerFailure>(),
      );

      for (final type in [
        DioExceptionType.badCertificate,
        DioExceptionType.transformTimeout,
      ]) {
        final failure = mapFailure(
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/me/home'),
            type: type,
          ),
          isRead: true,
        );

        expect(failure, isA<ServerFailure>());
        expect(failure.canRetry, isFalse);
      }
    });

    test('unwraps parallel failures and preserves NotFound', () async {
      await expectLater(
        (
          Future<int>.error(_httpError(500)),
          Future<int>.error(_httpError(404)),
        ).wait,
        throwsA(
          isA<ParallelWaitError<Object?, Object?>>().having(
            (error) => mapFailure(error, isRead: true),
            'mapped failure',
            isA<NotFoundFailure>(),
          ),
        ),
      );
    });

    test('executes a failed write once and returns Err', () async {
      var attempts = 0;

      final result = await apiResult<int>(() async {
        attempts++;
        throw TimeoutException('No answer');
      }, isRead: false);

      expect(attempts, 1);
      expect(
        result,
        isA<Err<int>>().having(
          (value) => value.failure.canRetry,
          'automatic retry',
          isFalse,
        ),
      );
    });
  });

  test('provider retry is limited to two unanswered-read retries', () {
    const read = OfflineFailure(isRead: true);
    const write = OfflineFailure(isRead: false);

    expect(appProviderRetry(0, read), const Duration(milliseconds: 300));
    expect(appProviderRetry(1, read), const Duration(milliseconds: 600));
    expect(appProviderRetry(2, read), isNull);
    expect(appProviderRetry(0, write), isNull);
    expect(appProviderRetry(0, const ForbiddenFailure()), isNull);
    expect(appProviderRetry(0, const ServerFailure()), isNull);
  });

  test('transport reads token changes and logs safe metadata', () async {
    final lines = <String>[];
    final container = ProviderContainer.test(
      retry: appProviderRetry,
      overrides: [
        appConfigProvider.overrideWithValue(_config('dev')),
        apiLogProvider.overrideWithValue(lines.add),
      ],
    );

    container
        .read(demoSessionProvider.notifier)
        .signIn(DemoPersona.lerato.email);

    final adapter = _Adapter();
    final dio = container.read(apiDioProvider)..httpClientAdapter = adapter;
    final tokens = container.read(accessTokenStoreProvider.notifier);

    expect(dio.options.connectTimeout, const Duration(seconds: 5));
    expect(dio.options.sendTimeout, const Duration(seconds: 15));
    expect(dio.options.receiveTimeout, const Duration(seconds: 45));

    tokens.save(value: 'first-private-token', expiresAtUtc: DateTime.utc(2099));

    await dio.get<Object?>('/api/v1/me/home');

    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer first-private-token',
    );

    tokens.save(
      value: 'second-private-token',
      expiresAtUtc: DateTime.utc(2099),
    );

    adapter
      ..statusCode = 403
      ..body = {
        'detail': 'This action is not permitted.',
        'correlationId': 'trace-transport-03',
        'member': 'private-member-name',
        'amount': 98765,
      }
      ..headers = {
        'set-cookie': ['private-response-cookie'],
      };

    final result = await apiResult(
      () => dio.post<Object?>(
        '/api/v1/payouts',
        data: {'member': 'private-member-name', 'amount': 98765},
        queryParameters: {'filter': 'private-query-value'},
        options: Options(headers: {'Cookie': 'private-request-cookie'}),
      ),
      isRead: false,
    );

    expect(
      result,
      isA<Err<Response<Object?>>>().having(
        (value) => value.failure,
        'failure',
        isA<ForbiddenFailure>(),
      ),
    );

    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer second-private-token',
    );

    expect(container.read(demoSessionProvider), DemoPersona.lerato);
    expect(
      container.read(accessTokenStoreProvider)?.value,
      'second-private-token',
    );
    expect(container.read(apiDioProvider), same(dio));

    expect(
      lines.last,
      matches(
        r'^POST /api/v1/payouts 403 \d+ms '
        r'correlationId=trace-transport-03$',
      ),
    );

    final output = lines.join('\n');

    for (final privateValue in [
      'first-private-token',
      'second-private-token',
      'private-member-name',
      '98765',
      'private-response-cookie',
      'private-request-cookie',
      'private-query-value',
      'This action is not permitted.',
    ]) {
      expect(output, isNot(contains(privateValue)));
    }

    adapter
      ..statusCode = 200
      ..body = <String, Object?>{}
      ..headers = {};

    tokens.save(
      value: 'expired-private-token',
      expiresAtUtc: DateTime.utc(2000),
    );

    await dio.get<Object?>('/api/v1/me/home');

    expect(adapter.requests.last.headers.containsKey('Authorization'), isFalse);

    container.read(demoSessionProvider.notifier).signOut();
    await container.pump();

    expect(container.read(accessTokenStoreProvider), isNull);
  });

  for (final flavor in ['staging', 'prod']) {
    test('$flavor transport requires HTTPS', () {
      final container = ProviderContainer.test(
        overrides: [appConfigProvider.overrideWithValue(_config(flavor))],
      );

      expect(
        () => container.read(apiDioProvider),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('require HTTPS'),
          ),
        ),
      );
    });
  }
}

AppConfig _config(String flavor) {
  return AppConfig.parse(
    nativeFlavor: flavor,
    configuredFlavor: flavor,
    apiBaseUrl: 'http://localhost:5227',
  );
}

DioException _httpError(
  int status, {
  Object? data,
  Map<String, List<String>> headers = const {},
}) {
  final options = RequestOptions(path: '/api/v1/me/home');

  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: data,
      headers: Headers.fromMap(headers),
    ),
  );
}

final class _Adapter implements HttpClientAdapter {
  int statusCode = 200;
  Object? body = <String, Object?>{};
  Map<String, List<String>> headers = {};
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);

    return Future.value(
      ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          ...headers,
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}
