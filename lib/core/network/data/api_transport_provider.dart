import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/network/data/failure_mapper.dart';
import 'package:ronditrack/core/session/access_token_store.dart';

part 'api_transport_provider.g.dart';

typedef ApiLog = void Function(String line);

@Riverpod(keepAlive: true)
ApiLog apiLog(Ref ref) => debugPrint;

@Riverpod(keepAlive: true)
Dio apiDio(Ref ref) {
  final config = ref.watch(appConfigProvider);

  if (config.flavor != AppFlavor.dev && config.apiBaseUrl.scheme != 'https') {
    throw StateError('Staging and prod API connections require HTTPS.');
  }

  final dio =
      Dio(
          BaseOptions(
            baseUrl: config.apiBaseUrl.toString(),
            connectTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 45),
            headers: const {'Accept': Headers.jsonContentType},
          ),
        )
        ..interceptors.addAll([
          _AuthorizationInterceptor(() => ref.read(accessTokenStoreProvider)),
          _SafeLogInterceptor(ref.watch(apiLogProvider)),
        ]);

  ref.onDispose(() => dio.close(force: true));

  return dio;
}

final class _AuthorizationInterceptor extends Interceptor {
  new(this.readToken);

  final AccessToken? Function() readToken;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.removeWhere(
      (name, value) => name.toLowerCase() == 'authorization',
    );

    final token = readToken();

    if (token != null && token.expiresAtUtc.isAfter(DateTime.now().toUtc())) {
      options.headers['Authorization'] = 'Bearer ${token.value}';
    }

    handler.next(options);
  }
}

final class _SafeLogInterceptor extends Interceptor {
  new(this.write);

  final ApiLog write;
  final _timers = Expando<Stopwatch>();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _timers[options] = Stopwatch()..start();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _record(response.requestOptions, status: response.statusCode);

    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    _record(
      error.requestOptions,
      status: error.response?.statusCode,
      correlationId: responseCorrelationId(error.response),
    );

    handler.next(error);
  }

  void _record(
    RequestOptions options, {
    required int? status,
    String? correlationId,
  }) {
    final timer = _timers[options];
    timer?.stop();
    _timers[options] = null;

    final elapsed = timer?.elapsedMilliseconds ?? 0;
    final reference = correlationId == null
        ? ''
        : ' correlationId=$correlationId';

    write(
      '${options.method.toUpperCase()} ${options.uri.path} '
      '${status ?? '-'} ${elapsed}ms$reference',
    );
  }
}
