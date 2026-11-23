import 'package:ronditrack/core/session/auth_models.dart';

abstract interface class RefreshTokenStore {
  Future<RefreshToken?> read();

  Future<void> write(RefreshToken token);

  Future<void> clear();
}

final class MemoryRefreshTokenStore implements RefreshTokenStore {
  new({RefreshToken? initialToken}) : _token = initialToken;

  RefreshToken? _token;

  @override
  Future<RefreshToken?> read() async => _token;

  @override
  Future<void> write(RefreshToken token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}
