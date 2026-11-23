import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';

part 'access_token_store.g.dart';

final class AccessToken {
  const AccessToken({
    required this.value,
    required this.expiresAtUtc,
    this.userId,
  });

  final String value;
  final DateTime expiresAtUtc;
  final String? userId;
}

@Riverpod(keepAlive: true)
class AccessTokenStore extends _$AccessTokenStore {
  @override
  AccessToken? build() {
    if (ref.watch(useApiRepositoriesProvider)) {
      return ref.watch(
        sessionStateProvider.select(
          (value) => switch (value) {
            AuthSignedIn(:final currentAccessToken) => currentAccessToken,
            AuthRestoring() || AuthSignedOut() => null,
          },
        ),
      );
    }

    ref.listen(demoSessionProvider, (_, next) {
      if (next == null) {
        state = null;
      }
    });

    return null;
  }

  void save({
    required String value,
    required DateTime expiresAtUtc,
    String? userId,
  }) {
    if (ref.read(useApiRepositoriesProvider)) {
      throw StateError('API access tokens are managed by the session.');
    }

    state = AccessToken(
      value: value,
      expiresAtUtc: expiresAtUtc.toUtc(),
      userId: userId,
    );
  }

  void clear() {
    if (ref.read(useApiRepositoriesProvider)) {
      throw StateError('Use the session coordinator to sign out.');
    }

    state = null;
  }
}
