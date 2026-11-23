import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/network/data/failure_mapper.dart';
import 'package:ronditrack/core/network/data/platform_adapter.dart';

part 'api_dio_factory.g.dart';

typedef ApiLog = void Function(String line);

@Riverpod(keepAlive: true)
ApiLog apiLog(Ref ref) => debugPrint;

String safeApiPath(String path) {
  return path.replaceAllMapped(
    RegExp(r'(/invites/)[^/]+'),
    (match) => '${match[1]}[redacted]',
  );
}

Dio createApiDio(
  AppConfig config, {
  required ApiLog writeLog,
  bool browserCookies = false,
}) {
  if (config.flavor != AppFlavor.dev && config.apiBaseUrl.scheme != 'https') {
    throw StateError('Staging and prod API connections require HTTPS.');
  }

  return Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl.toString(),
        connectTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 45),
        followRedirects: !browserCookies,
        headers: const {'Accept': Headers.jsonContentType},
      ),
    )
    ..httpClientAdapter = createPlatformAdapter(withCredentials: browserCookies)
    ..interceptors.add(_SafeLogInterceptor(writeLog));
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
      '${options.method.toUpperCase()} '
      '${safeApiPath(options.uri.path)} '
      '${status ?? '-'} ${elapsed}ms$reference',
    );
  }
}
