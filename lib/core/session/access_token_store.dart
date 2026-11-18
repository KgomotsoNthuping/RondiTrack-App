import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/session/demo_session.dart';

part 'access_token_store.g.dart';

final class AccessToken {
  const new({required this.value, required this.expiresAtUtc});

  final String value;
  final DateTime expiresAtUtc;
}

@Riverpod(keepAlive: true)
class AccessTokenStore extends _$AccessTokenStore {
  @override
  AccessToken? build() {
    ref.listen(demoSessionProvider, (previous, next) {
      if (next == null) {
        state = null;
      }
    });

    return null;
  }

  void save({required String value, required DateTime expiresAtUtc}) {
    state = AccessToken(value: value, expiresAtUtc: expiresAtUtc.toUtc());
  }

  void clear() {
    state = null;
  }
}
