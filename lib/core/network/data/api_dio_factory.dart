import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/network/data/failure_mapper.dart';
import 'package:ronditrack/core/network/data/platform_adapter.dart';
import 'package:ronditrack/core/observability/report_scrubber.dart';

part 'api_dio_factory.g.dart';

typedef ApiLog = void Function(String line);

@Riverpod(keepAlive: true)
ApiLog apiLog(Ref ref) => debugPrint;

String safeApiPath(String path) {
  const routes = {
    'api',
    'v1',
    'auth',
    'login',
    'register',
    'refresh',
    'logout',
    'me',
    'home',
    'stokvels',
    'cycles',
    'members',
    'contributions',
    'payments',
    'invites',
    'join',
    'activity',
    'profile',
  };

  final uri = Uri.tryParse(path);

  if (uri == null) {
    return '/[redacted]';
  }

  const dynamicAfter = {
    'stokvels',
    'cycles',
    'members',
    'contributions',
    'invites',
    'join',
  };

  final segments = uri.pathSegments;
  final safe = <String>[];

  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];

    final dynamicValue =
        index > 0 && dynamicAfter.contains(segments[index - 1]);

    safe.add(
      !dynamicValue && routes.contains(segment) ? segment : '[redacted]',
    );
  }

  return '/${safe.join('/')}';
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
    ..interceptors.add(
      _SafeLogInterceptor(
        kDebugMode && config.flavor == AppFlavor.dev ? writeLog : (_) {},
      ),
    );
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
    final safeReference = safeReportReference(correlationId);

    final reference = safeReference == null
        ? ''
        : ' correlationId=$safeReference';

    final requestedMethod = options.method.toUpperCase();

    final method =
        const {
          'GET',
          'HEAD',
          'POST',
          'PUT',
          'PATCH',
          'DELETE',
          'OPTIONS',
        }.contains(requestedMethod)
        ? requestedMethod
        : 'HTTP';

    write(
      '$method '
      '${safeApiPath(options.uri.path)} '
      '${status ?? '-'} ${elapsed}ms$reference',
    );
  }
}
