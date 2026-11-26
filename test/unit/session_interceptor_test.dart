import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/data/session_interceptor.dart';
import 'package:ronditrack/core/session/session_access.dart';

import '../support/assignment_12_1_fixtures.dart';
import '../support/scripted_http_adapter.dart';

void main() {
  Dio client(
    SessionAccess session,
    FutureOr<ResponseBody> Function(RequestOptions) respond,
  ) {
    final adapter = ScriptedHttpAdapter(respond);
    final options = BaseOptions(baseUrl: 'https://api.example.invalid');
    final retry = Dio(options)..httpClientAdapter = adapter;
    final dio = Dio(options)
      ..httpClientAdapter = adapter
      ..interceptors.add(
        SessionInterceptor.withSession(session: session, retryDio: retry),
      );

    addTearDown(() {
      dio.close(force: true);
      retry.close(force: true);
    });

    return dio;
  }

  MockSessionAccess mockSession() {
    final session = MockSessionAccess();
    final access = AccessToken(
      value: 'old-token',
      expiresAtUtc: testNow.add(const Duration(minutes: 10)),
      userId: testUserId,
    );

    when(() => session.epoch).thenReturn(7);
    when(() => session.state).thenReturn(
      AuthSignedIn(identity: testIdentity, accessToken: access, sessionId: 7),
    );
    when(() => session.tokenForRequest()).thenAnswer((_) async => Ok(access));

    return session;
  }

  test('401 refreshes once and replays with the replacement token', () async {
    final session = mockSession();
    final replacement = AccessToken(
      value: 'new-token',
      expiresAtUtc: testNow.add(const Duration(minutes: 20)),
      userId: testUserId,
    );
    when(() => session.refresh()).thenAnswer((_) async => Ok(replacement));

    final dio = client(session, (request) {
      return jsonResponse(
        request.headers['Authorization'] == 'Bearer old-token' ? 401 : 200,
        {'ok': true},
      );
    });

    final response = await dio.get<Object?>(
      '/protected',
      options: Options(
        headers: {
          'Authorization': 'Bearer supplied-by-caller',
          'Cookie': 'private-cookie',
        },
      ),
    );
    final requests = (dio.httpClientAdapter as ScriptedHttpAdapter).requests;

    expect(response.statusCode, 200);
    expect(requests, hasLength(2));
    expect(requests[0].headers['Authorization'], 'Bearer old-token');
    expect(requests[1].headers['Authorization'], 'Bearer new-token');
    expect(
      requests
          .expand((request) => request.headers.keys)
          .any((key) => key.toLowerCase() == 'cookie'),
      isFalse,
    );
    verify(() => session.tokenForRequest()).called(1);
    verify(() => session.refresh()).called(1);
  });

  test('403 never attempts a refresh', () async {
    final session = mockSession();
    final dio = client(session, (_) => jsonResponse(403, {}));

    await expectLater(
      dio.get<Object?>('/protected'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status',
          403,
        ),
      ),
    );

    verifyNever(() => session.refresh());
    expect(session.state, isA<AuthSignedIn>());
  });

  test('no signal never attempts a refresh', () async {
    final session = mockSession();
    final dio = client(session, (request) {
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      );
    });

    await expectLater(
      dio.get<Object?>('/protected'),
      throwsA(isA<DioException>()),
    );

    verifyNever(() => session.refresh());
    expect(session.state, isA<AuthSignedIn>());
  });

  test('concurrent 401 responses share the real coordinator refresh', () async {
    final h = await TestSession.start();
    addTearDown(h.dispose);
    final refreshStarted = Completer<void>();
    final bothUnauthorized = Completer<void>();
    final refreshed = Completer<Result<AuthTokens>>();
    var unauthorized = 0;

    when(() => h.api.refresh(refreshToken: any(named: 'refreshToken')))
        .thenAnswer((_) {
          if (!refreshStarted.isCompleted) {
            refreshStarted.complete();
          }
          return refreshed.future;
        });

    final dio = client(CoordinatorSessionAccess(h.coordinator), (request) {
      if (request.headers['Authorization'] == 'Bearer old-token') {
        unauthorized++;
        if (unauthorized == 2) {
          bothUnauthorized.complete();
        }
        return jsonResponse(401, {});
      }
      return jsonResponse(200, {'ok': true});
    });

    final pending = Future.wait([
      dio.get<Object?>('/one'),
      dio.get<Object?>('/two'),
    ]);

    await Future.wait([refreshStarted.future, bothUnauthorized.future])
        .timeout(const Duration(seconds: 3));

    refreshed.complete(Ok(testTokens('new-token')));
    final responses = await pending;
    final requests = (dio.httpClientAdapter as ScriptedHttpAdapter).requests;

    expect(responses.map((response) => response.statusCode), [200, 200]);
    expect(requests, hasLength(4));
    expect(
      requests.where(
        (request) => request.headers['Authorization'] == 'Bearer new-token',
      ),
      hasLength(2),
    );
    verify(() => h.api.refresh(refreshToken: any(named: 'refreshToken')))
        .called(1);
  });

  test('offline refresh keeps identity and refresh credentials', () async {
    final h = await TestSession.start();
    addTearDown(h.dispose);
    final before = h.coordinator.epoch;

    when(() => h.api.refresh(refreshToken: any(named: 'refreshToken')))
        .thenAnswer(
          (_) async => const Err<AuthTokens>(OfflineFailure(isRead: true)),
        );

    final dio = client(
      CoordinatorSessionAccess(h.coordinator),
      (_) => jsonResponse(401, {}),
    );

    await expectLater(
      dio.get<Object?>('/protected'),
      throwsA(
        isA<DioException>().having(
          (error) => error.error,
          'failure',
          isA<OfflineFailure>(),
        ),
      ),
    );

    expect(h.coordinator.epoch, before);
    expect(h.coordinator.state, isA<AuthSignedIn>());
    expect(
      (h.coordinator.state as AuthSignedIn).failure,
      isA<OfflineFailure>(),
    );
    expect((await h.store.read())?.value, 'refresh-old-token');
    verifyNever(() => h.api.logout(refreshToken: any(named: 'refreshToken')));
  });

  test('refused refresh ends authenticated access without replay', () async {
    final h = await TestSession.start();
    addTearDown(h.dispose);

    when(() => h.api.refresh(refreshToken: any(named: 'refreshToken')))
        .thenAnswer((_) async => const Err<AuthTokens>(UnauthorizedFailure()));

    final dio = client(
      CoordinatorSessionAccess(h.coordinator),
      (_) => jsonResponse(401, {}),
    );

    await expectLater(
      dio.get<Object?>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(h.coordinator.state, isA<AuthSignedOut>());
    expect(await h.store.read(), isNull);
    expect(await h.coordinator.tokenForRequest(), isA<Err<AccessToken>>());
    expect(
      (dio.httpClientAdapter as ScriptedHttpAdapter).requests,
      hasLength(1),
    );
    verify(() => h.api.refresh(refreshToken: any(named: 'refreshToken')))
        .called(1);
  });
}
