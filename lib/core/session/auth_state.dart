import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/auth_models.dart';

sealed class AuthState {
  const new();
}

final class AuthRestoring extends AuthState {
  const new({this.failure});

  final Failure? failure;
}

final class AuthSignedOut extends AuthState {
  const new({this.failure});

  final Failure? failure;
}

final class AuthSignedIn extends AuthState {
  const new({
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
