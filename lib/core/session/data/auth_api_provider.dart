import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/config/auth_config.dart';
import 'package:ronditrack/core/network/data/api_dio_factory.dart';
import 'package:ronditrack/core/network/data/platform_adapter.dart';
import 'package:ronditrack/core/session/auth_api.dart';
import 'package:ronditrack/core/session/data/dio_auth_api.dart';

part 'auth_api_provider.g.dart';

@Riverpod(keepAlive: true)
Dio authDio(Ref ref) {
  final dio = createApiDio(
    ref.watch(appConfigProvider),
    writeLog: ref.watch(apiLogProvider),
    browserCookies: true,
  );

  ref.onDispose(() => dio.close(force: true));

  return dio;
}

@Riverpod(keepAlive: true)
AuthApi authApi(Ref ref) {
  final api = DioAuthApi(
    dio: ref.watch(authDioProvider),
    config: ref.watch(authConfigProvider),
    browserManagedCookies: platformUsesBrowserCookies,
  );

  ref.onDispose(api.cancelPending);

  return api;
}
