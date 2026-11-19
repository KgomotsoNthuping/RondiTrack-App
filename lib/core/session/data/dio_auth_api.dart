import 'dart:async';

import 'package:dio/dio.dart';
import 'package:ronditrack/core/config/auth_config.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/api_result.dart';
import 'package:ronditrack/core/network/data/failure_mapper.dart';
import 'package:ronditrack/core/network/data/generated/models/auth_response.dart';
import 'package:ronditrack/core/network/data/generated/models/login_request.dart';
import 'package:ronditrack/core/network/data/generated/models/register_request.dart';
import 'package:ronditrack/core/network/data/generated/models/user_response.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_api.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/data/auth_claims.dart';
import 'package:ronditrack/core/session/data/auth_cookie.dart';
import 'package:ronditrack/core/session/data/auth_paths.dart';

final class DioAuthApi implements AuthApi {
  DioAuthApi({
    required Dio dio,
    required AuthConfig config,
    required this.browserManagedCookies,
  }) : _dio = dio,
       _config = config;

  final Dio _dio;
  final AuthConfig _config;
  CancelToken _pending = CancelToken();

  @override
  final bool browserManagedCookies;

  @override
  Future<Result<AuthTokens>> signIn({
    required String email,
    required String password,
  }) {
    return apiResult(() async {
      final response = await _dio.post<Object?>(
        AuthPaths.login,
        data: LoginRequest(email: email, password: password).toJson(),
        cancelToken: _pending,
      );

      return _readTokens(response);
    }, isRead: false);
  }

  @override
  Future<Result<RegisteredAccount>> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) {
    return apiResult(() async {
      final response = await _dio.post<Object?>(
        AuthPaths.register,
        data: RegisterRequest(
          fullName: fullName,
          email: email,
          phoneNumber: phoneNumber,
          password: password,
        ).toJson(),
        cancelToken: _pending,
      );

      return _decode(response, (json) {
        final account = UserResponse.fromJson(json);

        return RegisteredAccount(
          userId: account.id,
          fullName: account.fullName,
          email: account.email,
          phoneNumber: account.phoneNumber,
          version: account.version,
        );
      });
    }, isRead: false);
  }

  @override
  Future<Result<AuthTokens>> refresh({RefreshToken? refreshToken}) {
    return apiResult(() async {
      final response = await _dio.post<Object?>(
        AuthPaths.refresh,
        options: _options(AuthPaths.refresh, token: refreshToken),
        cancelToken: _pending,
      );

      return _readTokens(response);
    }, isRead: false);
  }

  @override
  Future<Result<void>> logout({RefreshToken? refreshToken}) {
    return apiResult<void>(() async {
      final cancellation = CancelToken();
      const timeout = Duration(seconds: 2);

      await _dio
          .post<Object?>(
            AuthPaths.logout,
            options: _options(
              AuthPaths.logout,
              token: refreshToken,
              timeout: timeout,
            ),
            cancelToken: cancellation,
          )
          .timeout(
            timeout,
            onTimeout: () {
              cancellation.cancel('Logout timed out.');
              throw TimeoutException('Logout timed out.');
            },
          );
    }, isRead: false);
  }

  @override
  void cancelPending() {
    _pending.cancel('Authentication operation cancelled.');
    _pending = CancelToken();
  }

  Options _options(String path, {RefreshToken? token, Duration? timeout}) {
    if (browserManagedCookies && token != null) {
      throw const FormatException(
        'Browser refresh cookies cannot be supplied manually.',
      );
    }

    return Options(
      sendTimeout: timeout,
      receiveTimeout: timeout,
      headers: {
        if (token != null)
          'Cookie': refreshCookieHeader(token, _config, path: path),
      },
    );
  }

  AuthTokens _readTokens(Response<Object?> response) {
    return _decode(response, (json) {
      final result = AuthResponse.fromJson(json);

      return AuthTokens(
        accessToken: result.accessToken,
        expiresAtUtc: result.expiresAtUtc.toUtc(),
        identity: decodeAuthClaims(result.accessToken),
        refreshToken: browserManagedCookies
            ? null
            : readRefreshCookie(
                response.headers['set-cookie'] ?? const [],
                _config,
              ),
      );
    });
  }

  T _decode<T>(
    Response<Object?> response,
    T Function(Map<String, Object?> json) decode,
  ) {
    try {
      final data = response.data;

      if (data is! Map<String, Object?>) {
        throw const FormatException('Invalid authentication response.');
      }

      return decode(data);
    } on Object {
      throw ServerFailure(correlationId: responseCorrelationId(response));
    }
  }
}
