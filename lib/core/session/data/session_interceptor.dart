import 'dart:async';

import 'package:dio/dio.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/data/auth_paths.dart';
import 'package:ronditrack/core/session/session_coordinator.dart';

final class SessionInterceptor extends Interceptor {
  SessionInterceptor({
    required SessionCoordinator session,
    required Dio retryDio,
  }) : _session = session,
       _retryDio = retryDio;

  final SessionCoordinator _session;
  final Dio _retryDio;

  static const _epochKey = 'ronditrack.sessionEpoch';
  static const _retryKey = 'ronditrack.sessionRetried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    unawaited(_prepare(options, handler));
  }

  Future<void> _prepare(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      options.headers.removeWhere((name, _) {
        final lower = name.toLowerCase();

        return lower == 'authorization' || lower == 'cookie';
      });

      final target = options.uri;
      final base = Uri.parse(options.baseUrl);

      if (target.scheme != base.scheme ||
          target.host != base.host ||
          target.port != base.port ||
          const [
            AuthPaths.login,
            AuthPaths.register,
            AuthPaths.refresh,
            AuthPaths.logout,
          ].contains(target.path)) {
        handler.reject(
          _failure(
            options,
            const RuleFailure(
              detail: 'Use the configured API and the separate auth client.',
            ),
          ),
        );
        return;
      }

      final generation = _session.epoch;
      final result = await _session.tokenForRequest();

      if (generation != _session.epoch ||
          options.cancelToken?.isCancelled == true) {
        handler.reject(_cancelled(options));
        return;
      }

      switch (result) {
        case Ok<AccessToken>(:final value):
          options.headers['Authorization'] = 'Bearer ${value.value}';
          options.extra[_epochKey] = generation;
          handler.next(options);

        case Err<AccessToken>(:final failure):
          handler.reject(_failure(options, failure));
      }
    } on Object {
      handler.reject(_failure(options, const ServerFailure()));
    }
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (response.requestOptions.extra[_epochKey] != _session.epoch) {
      handler.reject(_cancelled(response.requestOptions));
      return;
    }

    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    unawaited(_recover(error, handler));
  }

  Future<void> _recover(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final options = error.requestOptions;
    final generation = options.extra[_epochKey];

    if (generation != null && generation != _session.epoch) {
      handler.reject(_cancelled(options));
      return;
    }

    if (generation == null ||
        error.response?.statusCode != 401 ||
        options.extra[_retryKey] == true ||
        options.data is Stream<Object?>) {
      handler.next(error);
      return;
    }

    try {
      final current = _session.state;

      if (current is! AuthSignedIn) {
        handler.next(error);
        return;
      }

      final sent = options.headers['Authorization'];

      final result = sent != 'Bearer ${current.accessToken.value}'
          ? Ok(current.accessToken)
          : await _session.refresh();

      if (generation != _session.epoch ||
          options.cancelToken?.isCancelled == true) {
        handler.reject(_cancelled(options));
        return;
      }

      if (result case Err<AccessToken>(:final failure)) {
        handler.reject(_failure(options, failure));
        return;
      }

      final access = (result as Ok<AccessToken>).value;

      final headers = Map<String, dynamic>.from(options.headers)
        ..removeWhere((name, _) {
          final lower = name.toLowerCase();

          return lower == 'authorization' || lower == 'cookie';
        })
        ..['Authorization'] = 'Bearer ${access.value}';

      final data = options.data;

      final replay = options.copyWith(
        headers: headers,
        extra: {...options.extra, _retryKey: true},
        data: data is FormData ? data.clone() : data,
      );

      final response = await _retryDio.fetch<dynamic>(replay);

      if (generation != _session.epoch) {
        handler.reject(_cancelled(options));
        return;
      }

      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.reject(
        generation == _session.epoch ? retryError : _cancelled(options),
      );
    } on Object {
      handler.reject(_failure(options, const ServerFailure()));
    }
  }

  DioException _failure(RequestOptions options, Failure failure) {
    return DioException(requestOptions: options, error: failure);
  }

  DioException _cancelled(RequestOptions options) {
    return DioException(
      requestOptions: options,
      type: DioExceptionType.cancel,
      error: const OfflineFailure(isRead: false),
    );
  }
}
