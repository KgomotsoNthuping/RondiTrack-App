import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/push/data/dio_device_api.dart';
import 'package:ronditrack/core/session/access_token_store.dart';

import '../support/scripted_http_adapter.dart';

void main() {
  final access = AccessToken(
    value: 'snapshot-token',
    expiresAtUtc: DateTime.utc(2030),
    userId: '11111111-1111-4111-8111-111111111111',
  );

  test(
    'uses the signed-in snapshot and the exact registration contract',
    () async {
      final adapter = ScriptedHttpAdapter((_) => jsonResponse(204, null));

      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'))
        ..httpClientAdapter = adapter;

      addTearDown(() => dio.close(force: true));

      final api = DioDeviceApi(dio);

      expect(await api.register('fid-one', access), isTrue);
      expect(await api.forget('fid-one', access), isTrue);

      final registration = adapter.requests.first;

      expect(registration.method, 'POST');
      expect(registration.path, '/api/v1/me/devices');
      expect(registration.headers['Authorization'], 'Bearer snapshot-token');
      expect(registration.body, {
        'installationId': 'fid-one',
        'platform': 'android',
      });

      expect(adapter.requests.last.method, 'DELETE');
      expect(adapter.requests.last.path, '/api/v1/me/devices/fid-one');
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer snapshot-token',
      );
    },
  );

  test('missing endpoints fail quietly', () async {
    final adapter = ScriptedHttpAdapter(
      (_) => jsonResponse(404, {'title': 'Not found'}),
    );

    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'))
      ..httpClientAdapter = adapter;

    addTearDown(() => dio.close(force: true));

    final api = DioDeviceApi(dio);

    expect(await api.register('fid-one', access), isFalse);
    expect(await api.forget('fid-one', access), isFalse);
  });

  test(
    'an unexpected success status is not registration confirmation',
    () async {
      final adapter = ScriptedHttpAdapter((_) => jsonResponse(200, const {}));

      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'))
        ..httpClientAdapter = adapter;

      addTearDown(() => dio.close(force: true));

      expect(await DioDeviceApi(dio).register('fid-one', access), isFalse);
    },
  );
}
