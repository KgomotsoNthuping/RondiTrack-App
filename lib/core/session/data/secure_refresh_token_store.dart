import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/refresh_token_store.dart';

part 'secure_refresh_token_store.g.dart';

@Riverpod(keepAlive: true)
RefreshTokenStore refreshTokenStore(Ref ref) {
  if (kIsWeb) {
    throw UnsupportedError(
      'Chrome refresh cookies are managed by the browser.',
    );
  }

  final config = ref.watch(appConfigProvider);
  final origin = Uri.encodeComponent(config.apiBaseUrl.toString());

  return SecureRefreshTokenStore(
    storage: const FlutterSecureStorage(),
    key: 'ronditrack.auth.${config.flavor.name}.$origin.refresh',
  );
}

final class SecureRefreshTokenStore implements RefreshTokenStore {
  const SecureRefreshTokenStore({
    required FlutterSecureStorage storage,
    required String key,
  }) : _storage = storage,
       _key = key;

  final FlutterSecureStorage _storage;
  final String _key;

  @override
  Future<RefreshToken?> read() async {
    final value = await _storage.read(key: _key);

    return value == null ? null : RefreshToken(value);
  }

  @override
  Future<void> write(RefreshToken token) {
    return _storage.write(key: _key, value: token.value);
  }

  @override
  Future<void> clear() {
    return _storage.deleteAll();
  }
}
