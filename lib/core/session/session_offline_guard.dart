part of 'session_coordinator.dart';

extension SessionOfflineActions on SessionCoordinator {
  bool get _requiresReauthentication {
    final current = _state;

    return current is AuthSignedIn && current.failure is UnauthorizedFailure;
  }

  Future<Result<void>> _guardPendingExit(Failure? reason) async {
    final generation = _epoch;

    try {
      final pending = await _persistence!.hasPendingPayments();

      if (!_current(generation)) {
        return const Err(_cancelled);
      }

      if (!pending) {
        return await _finishSignOut(reason: reason);
      }

      final current = _state;

      if (reason is UnauthorizedFailure && current is AuthSignedIn) {
        final next = ++_epoch;

        _persistence.invalidateWrites();
        _api.cancelPending();
        _restoreFlight = null;
        _refreshFlight = null;

        _publish(
          AuthSignedIn(
            identity: current.identity,
            accessToken: null,
            sessionId: next,
            failure: reason,
          ),
        );

        if (!_api.browserManagedCookies) {
          await _serial(() async {
            if (_current(next)) {
              await _store!.clear();
            }
          });
        }
      }

      return const Err(
        RuleFailure(
          detail:
              'Pending payments are saved. Confirm before '
              'discarding them.',
        ),
      );
    } on Object {
      return const Err(ServerFailure());
    }
  }

  Future<Result<void>> reauthenticate({
    required String email,
    required String password,
  }) async {
    final previous = _state;

    if (_closed || _authenticating || previous is! AuthSignedIn) {
      return const Err(UnauthorizedFailure());
    }

    _authenticating = true;
    final generation = ++_epoch;

    _persistence?.invalidateWrites();
    _api.cancelPending();
    _restoreFlight = null;
    _refreshFlight = null;

    void retainAccount(Failure failure) {
      if (!_current(generation)) {
        return;
      }

      _publish(
        AuthSignedIn(
          identity: previous.identity,
          accessToken: null,
          sessionId: generation,
          failure: const UnauthorizedFailure(),
        ),
      );
    }

    try {
      final result = await _api.signIn(email: email, password: password);

      if (!_current(generation)) {
        return const Err(_cancelled);
      }

      switch (result) {
        case Err<AuthTokens>(:final failure):
          retainAccount(failure);
          return Err(failure);

        case Ok<AuthTokens>(:final value):
          if (value.identity.userId != previous.identity.userId) {
            const failure = RuleFailure(
              detail: 'Sign out before using another account.',
            );

            retainAccount(failure);
            return const Err(failure);
          }

          if (!await _persist(value, generation, signIn: true)) {
            return const Err(_cancelled);
          }

          _publishSignedIn(value, generation);
          return const Ok(null);
      }
    } on Object {
      const failure = ServerFailure();
      retainAccount(failure);
      return const Err(failure);
    } finally {
      _authenticating = false;
    }
  }
}
