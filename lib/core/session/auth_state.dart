import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/auth_models.dart';

sealed class AuthState {
  const AuthState();
}

final class AuthRestoring extends AuthState {
  const AuthRestoring({this.failure});

  final Failure? failure;
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.failure});

  final Failure? failure;
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn({
    required this.identity,
    required AccessToken? accessToken,
    required this.sessionId,
    this.failure,
  }) : currentAccessToken = accessToken;

  final AuthIdentity identity;
  final AccessToken? currentAccessToken;
  final int sessionId;
  final Failure? failure;

  bool get isOffline => currentAccessToken == null;

  AccessToken get accessToken {
    final token = currentAccessToken;

    if (token == null) {
      throw StateError('This cached account has no access token.');
    }

    return token;
  }
}