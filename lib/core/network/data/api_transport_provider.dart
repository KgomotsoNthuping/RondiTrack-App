import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/network/data/api_dio_factory.dart';
import 'package:ronditrack/core/network/data/session_transport_provider.dart';
import 'package:ronditrack/core/session/access_token_store.dart';

export 'api_dio_factory.dart' show ApiLog, apiLogProvider, createApiDio;

part 'api_transport_provider.g.dart';

@Riverpod(keepAlive: true)
Dio apiDio(Ref ref) {
  if (ref.watch(useApiRepositoriesProvider)) {
    return ref.watch(sessionDioProvider);
  }

  final dio = createApiDio(
    ref.watch(appConfigProvider),
    writeLog: ref.watch(apiLogProvider),
  );

  dio.interceptors.insert(
    0,
    _FixtureAuthorizationInterceptor(() => ref.read(accessTokenStoreProvider)),
  );

  ref.onDispose(() => dio.close(force: true));

  return dio;
}

final class _FixtureAuthorizationInterceptor extends Interceptor {
  new(this.readToken);

  final AccessToken? Function() readToken;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.removeWhere(
      (name, _) => name.toLowerCase() == 'authorization',
    );

    final token = readToken();

    if (token != null && token.expiresAtUtc.isAfter(DateTime.now().toUtc())) {
      options.headers['Authorization'] = 'Bearer ${token.value}';
    }

    handler.next(options);
  }
}
