import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/api_dio_factory.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/features/invites/data/api_invite_repository.dart';
import 'package:ronditrack/features/invites/domain/invite_repository.dart';

void main() {
  test('reads preview and join response fields', () async {
    final adapter = _Adapter()
      ..body = {
        'stokvelId': 'stokvel-id',
        'name': 'Test stokvel',
        'alreadyMember': false,
        'contributionAmountInCents': 50000,
        'memberCount': 3,
      };

    final repository = _repository(adapter);

    final preview = await repository.preview('private-code');

    expect(preview, isA<Ok<InvitePreview>>());
    expect((preview as Ok<InvitePreview>).value.alreadyMember, isFalse);

    adapter.body = {
      'stokvelId': 'stokvel-id',
      'name': 'Test stokvel',
      'role': 'Member',
    };

    final joined = await repository.join('private-code');

    expect(joined, isA<Ok<JoinedInvite>>());
    expect(adapter.requests.last.path, '/api/v1/invites/private-code/join');
    expect(adapter.requests.last.method, 'POST');
    expect(adapter.requests.last.data, isNull);
  });

  for (final (status, expected) in [
    (404, NotFoundFailure),
    (409, ConflictFailure),
    (410, RuleFailure),
  ]) {
    test('maps invite HTTP $status', () async {
      final adapter = _Adapter()..status = status;

      final result = await _repository(adapter).preview('private-code');

      expect(result, isA<Err<InvitePreview>>());

      final failure = (result as Err<InvitePreview>).failure;

      expect(failure.runtimeType, expected);

      if (status == 410) {
        expect(failure.message, expiredInviteMessage);
      }
    });
  }

  test('rejects path fragments before sending a request', () async {
    final adapter = _Adapter();

    final result = await _repository(adapter).preview('../auth/logout');

    expect(result, isA<Err<InvitePreview>>());
    expect(adapter.requests, isEmpty);
  });

  test('logs no invite code', () async {
    final lines = <String>[];

    final adapter = _Adapter()
      ..body = {
        'stokvelId': 'stokvel-id',
        'name': 'Test stokvel',
        'alreadyMember': true,
      };

    await _repository(adapter, log: lines.add).preview('private-code');

    expect(lines, hasLength(1));
    expect(lines.single, contains('/invites/[redacted]'));
    expect(lines.single, isNot(contains('private-code')));
  });
}

ApiInviteRepository _repository(_Adapter adapter, {ApiLog? log}) {
  final dio = createApiDio(
    AppConfig.parse(
      nativeFlavor: 'dev',
      configuredFlavor: 'dev',
      apiBaseUrl: 'http://localhost:5227',
    ),
    writeLog: log ?? (_) {},
  )..httpClientAdapter = adapter;

  addTearDown(() => dio.close(force: true));

  return ApiInviteRepository(dio);
}

final class _Adapter implements HttpClientAdapter {
  int status = 200;
  Object? body = <String, Object?>{};

  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
