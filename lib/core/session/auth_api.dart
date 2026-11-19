import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_models.dart';

abstract interface class AuthApi {
  bool get browserManagedCookies;

  Future<Result<AuthTokens>> signIn({
    required String email,
    required String password,
  });

  Future<Result<RegisteredAccount>> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  });

  Future<Result<AuthTokens>> refresh({RefreshToken? refreshToken});

  Future<Result<void>> logout({RefreshToken? refreshToken});

  void cancelPending();
}
