import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/api_client.dart';
import 'package:ronditrack/core/network/data/api_result.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/network/data/generated/models/login_request.dart';
import 'package:ronditrack/core/network/data/generated/rondi_track_api.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/access_token_store.dart';

part 'api_auth_repository.g.dart';

@Riverpod(keepAlive: true)
ApiAuthRepository apiAuthRepository(Ref ref) {
  return ApiAuthRepository(ref.watch(apiDioProvider));
}

final class ApiAuthRepository {
  new(Dio dio) : _api = createApiClient(dio);

  final RondiTrackApi _api;

  Future<Result<AccessToken>> signIn({
    required String email,
    required String password,
  }) {
    return apiResult(() async {
      final response = await _api.auth.postApiV1AuthLogin(
        body: LoginRequest(email: email, password: password),
      );

      final data = response.data;
      final expiresAt = data.expiresAtUtc.toUtc();

      if (!expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const UnauthorizedFailure();
      }

      return AccessToken(
        value: data.accessToken,
        expiresAtUtc: expiresAt,
        userId: _subject(data.accessToken),
      );
    }, isRead: false);
  }
}

String _subject(String token) {
  final parts = token.split('.');

  if (parts.length != 3) {
    throw const FormatException('Invalid access token.');
  }

  final Object? payload = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
  );

  if (payload is! Map<String, Object?>) {
    throw const FormatException('Invalid access token payload.');
  }

  final subject =
      payload['sub'] ??
      payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'];

  if (subject is! String || subject.isEmpty) {
    throw const FormatException('Missing access token subject.');
  }

  return subject;
}
