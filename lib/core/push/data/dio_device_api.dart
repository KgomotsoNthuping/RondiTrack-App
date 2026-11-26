import 'package:dio/dio.dart';
import 'package:ronditrack/core/push/device_api.dart';
import 'package:ronditrack/core/session/access_token_store.dart';

final class DioDeviceApi implements DeviceApi {
  new(this.dio);

  final Dio dio;
  final _pending = <CancelToken>{};

  @override
  Future<bool> register(String installationId, AccessToken access) => _request(
    'POST',
    '/api/v1/me/devices',
    access,
    body: {'installationId': installationId, 'platform': 'android'},
  );

  @override
  Future<bool> forget(String installationId, AccessToken access) => _request(
    'DELETE',
    '/api/v1/me/devices/'
        '${Uri.encodeComponent(installationId)}',
    access,
  );

  Future<bool> _request(
    String method,
    String path,
    AccessToken access, {
    Map<String, String>? body,
  }) async {
    final cancel = CancelToken();
    _pending.add(cancel);

    try {
      final response = await dio
          .request<Object?>(
            path,
            data: body,
            cancelToken: cancel,
            options: Options(
              method: method,
              followRedirects: false,
              contentType: Headers.jsonContentType,
              headers: {'Authorization': 'Bearer ${access.value}'},
            ),
          )
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              cancel.cancel();
              throw StateError('Device request timed out.');
            },
          );

      return response.statusCode == 204;
    } on Object {
      return false;
    } finally {
      _pending.remove(cancel);
    }
  }

  @override
  void cancelPending() {
    for (final cancel in _pending.toList()) {
      cancel.cancel();
    }
  }
}
