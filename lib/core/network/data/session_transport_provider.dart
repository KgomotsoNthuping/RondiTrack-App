import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/network/data/api_dio_factory.dart';
import 'package:ronditrack/core/session/data/session_interceptor.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';

part 'session_transport_provider.g.dart';

@Riverpod(keepAlive: true)
Dio sessionRetryDio(Ref ref) {
  final dio = createApiDio(
    ref.watch(appConfigProvider),
    writeLog: ref.watch(apiLogProvider),
  )..options.followRedirects = false;

  ref.onDispose(() => dio.close(force: true));

  return dio;
}

@Riverpod(keepAlive: true)
Dio sessionDio(Ref ref) {
  final dio = createApiDio(
    ref.watch(appConfigProvider),
    writeLog: ref.watch(apiLogProvider),
  )..options.followRedirects = false;

  dio.interceptors.add(
    SessionInterceptor(
      session: ref.watch(sessionCoordinatorProvider),
      retryDio: ref.watch(sessionRetryDioProvider),
    ),
  );

  ref.onDispose(() => dio.close(force: true));

  return dio;
}
