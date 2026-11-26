import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/network/data/api_dio_factory.dart';

import '../support/scripted_http_adapter.dart';

void main() {
  test('route logs discard ids, names and query parameters', () {
    expect(
      safeApiPath(
        '/api/v1/stokvels/Thandi%20Nkosi/contributions'
        '?token=secret&amount=1250.50',
      ),
      '/api/v1/stokvels/[redacted]/contributions',
    );

    for (final code in ['private-code', 'home']) {
      expect(
        safeApiPath('/api/v1/invites/$code'),
        '/api/v1/invites/[redacted]',
      );
    }
  });

  for (final flavor in ['staging', 'prod']) {
    test('$flavor produces no API console log', () async {
      final lines = <String>[];

      final dio =
          createApiDio(
              AppConfig.parse(
                nativeFlavor: flavor,
                configuredFlavor: flavor,
                apiBaseUrl: 'https://api.example.invalid',
              ),
              writeLog: lines.add,
            )
            ..httpClientAdapter = ScriptedHttpAdapter(
              (_) => jsonResponse(200, const {}),
            );

      addTearDown(() => dio.close(force: true));

      await dio.get<Object?>('/api/v1/me/home');

      expect(lines, isEmpty);
    });
  }

  test('dev logs contain only safe HTTP metadata', () async {
    final lines = <String>[];

    final dio =
        createApiDio(
            AppConfig.parse(
              nativeFlavor: 'dev',
              configuredFlavor: 'dev',
              apiBaseUrl: 'https://api.example.invalid',
            ),
            writeLog: lines.add,
          )
          ..httpClientAdapter = ScriptedHttpAdapter(
            (_) => jsonResponse(200, const {}),
          );

    addTearDown(() => dio.close(force: true));

    await dio.get<Object?>(
      '/api/v1/stokvels/Thandi/contributions',
      queryParameters: const {'email': 'thandi@example.invalid'},
      options: Options(headers: const {'Authorization': 'Bearer private'}),
    );

    expect(lines, hasLength(1));
    expect(
      lines.single,
      matches(
        r'^GET /api/v1/stokvels/\[redacted\]/contributions 200 [0-9]+ms$',
      ),
    );
    expect(lines.single, isNot(contains('Thandi')));
    expect(lines.single, isNot(contains('@')));
    expect(lines.single, isNot(contains('Bearer')));
  });
}
