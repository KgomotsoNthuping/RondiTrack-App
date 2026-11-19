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
    required this.accessToken,
    required this.sessionId,
  });

  final AuthIdentity identity;
  final AccessToken accessToken;
  final int sessionId;
}
