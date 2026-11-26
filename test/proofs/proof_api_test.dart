import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/data/session_interceptor.dart';
import 'package:ronditrack/features/proofs/data/dio_proof_uploader.dart';

import '../support/assignment_12_1_fixtures.dart';
import '../support/proof_fakes.dart';
import '../support/scripted_http_adapter.dart';

void main() {
  test(
    'multipart uses the session interceptor and can replay after 401',
    () async {
      final session = MockSessionAccess();

      final oldAccess = AccessToken(
        value: 'old-token',
        expiresAtUtc: testNow.add(const Duration(minutes: 10)),
        userId: testUserId,
      );

      final newAccess = AccessToken(
        value: 'new-token',
        expiresAtUtc: testNow.add(const Duration(minutes: 20)),
        userId: testUserId,
      );

      when(() => session.epoch).thenReturn(7);

      when(() => session.state).thenReturn(
        AuthSignedIn(
          identity: testIdentity,
          accessToken: oldAccess,
          sessionId: 7,
        ),
      );

      when(() => session.tokenForRequest())
          .thenAnswer((_) async => Ok(oldAccess));

      when(() => session.refresh()).thenAnswer((_) async => Ok(newAccess));

      final adapter = _CaptureAdapter();

      final retry = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'))
        ..httpClientAdapter = adapter;

      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          SessionInterceptor.withSession(session: session, retryDio: retry),
        );

      addTearDown(() {
        dio.close(force: true);
        retry.close(force: true);
      });

      final api = DioProofUploader(() => dio, testProofSettings);

      final photo = preparedTestProof();

      final id = await api.upload(
        testProofTarget,
        photo,
        onProgress: (_, _) {},
      );

      expect(id, testProofId);
      expect(adapter.requests, hasLength(2));
      expect(adapter.headers, ['Bearer old-token', 'Bearer new-token']);

      for (final request in adapter.requests) {
        expect(request.path, testProofTarget.uploadPath);
        expect(request.followRedirects, isFalse);

        final form = request.data as FormData;

        expect(form.fields, isEmpty);
        expect(form.files, hasLength(1));
        expect(form.files.single.key, 'file');
        expect(form.files.single.value.filename, 'proof.jpg');
        expect(form.files.single.value.contentType.toString(), 'image/jpeg');
        expect(form.files.single.value.length, photo.bytes.length);
      }

      for (final body in adapter.bodies) {
        expect(_containsBytes(body, photo.bytes), isTrue);
      }

      verify(() => session.refresh()).called(1);
    },
  );

  test(
    '413 becomes a readable upload-limit failure with its reference',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'))
        ..httpClientAdapter = ScriptedHttpAdapter(
          (_) => jsonResponse(413, {'correlationId': 'proof-limit-413'}),
        );

      addTearDown(() => dio.close(force: true));

      final api = DioProofUploader(() => dio, testProofSettings);

      await expectLater(
        api.upload(testProofTarget, preparedTestProof(), onProgress: (_, _) {}),
        throwsA(
          isA<ValidationFailure>()
              .having(
                (value) => value.message,
                'message',
                contains('upload limit'),
              )
              .having(
                (value) => value.correlationId,
                'reference',
                'proof-limit-413',
              ),
        ),
      );
    },
  );

  test('malformed success is not reported as an uploaded proof', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'))
      ..httpClientAdapter = ScriptedHttpAdapter(
        (_) => jsonResponse(201, {
          'proofId': 'https://example.invalid/private-photo',
        }),
      );

    addTearDown(() => dio.close(force: true));

    final api = DioProofUploader(() => dio, testProofSettings);

    await expectLater(
      api.upload(testProofTarget, preparedTestProof(), onProgress: (_, _) {}),
      throwsA(isA<ServerFailure>()),
    );
  });
}

final class _CaptureAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final headers = <String?>[];
  final bodies = <Uint8List>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = BytesBuilder(copy: false);

    if (requestStream != null) {
      await for (final chunk in requestStream) {
        body.add(chunk);
      }
    }

    requests.add(options);
    headers.add(options.headers['Authorization'] as String?);
    bodies.add(body.takeBytes());

    return requests.length == 1
        ? jsonResponse(401, {})
        : jsonResponse(201, {'proofId': testProofId});
  }

  @override
  void close({bool force = false}) {}
}

bool _containsBytes(Uint8List source, Uint8List wanted) {
  for (var offset = 0; offset <= source.length - wanted.length; offset++) {
    var matches = true;

    for (var index = 0; index < wanted.length; index++) {
      if (source[offset + index] != wanted[index]) {
        matches = false;
        break;
      }
    }

    if (matches) {
      return true;
    }
  }

  return false;
}
