import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';

part 'account_key.g.dart';

typedef AccountKey = ({String userId, int sessionId});

AccountKey? accountFromState(AuthState state) => switch (state) {
  AuthSignedIn(:final identity, :final sessionId) => (
    userId: identity.userId,
    sessionId: sessionId,
  ),
  AuthRestoring() || AuthSignedOut() => null,
};

@Riverpod(keepAlive: true, dependencies: [])
AccountKey? accountKey(Ref ref) {
  if (!ref.watch(useApiRepositoriesProvider)) {
    return null;
  }

  return ref.watch(sessionStateProvider.select(accountFromState));
}

AccountKey? requireAccount(Ref ref, {String? userId}) {
  final account = ref.watch(accountKeyProvider);

  if (ref.watch(useApiRepositoriesProvider) &&
      (account == null || (userId != null && userId != account.userId))) {
    throw const UnauthorizedFailure();
  }

  return account;
}

@Riverpod(keepAlive: true, dependencies: [accountKey])
class MembershipRevision extends _$MembershipRevision {
  @override
  int build() {
    ref.watch(accountKeyProvider);
    return 0;
  }

  void changed() => state++;
}
