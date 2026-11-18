import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/features/auth/data/api_auth_repository.dart';

part 'dev_sign_in_provider.g.dart';

@Riverpod(keepAlive: true)
class DevSignIn extends _$DevSignIn {
  int _attempt = 0;

  @override
  AsyncValue<void> build() {
    ref.listen(demoSessionProvider, (previous, next) {
      if (previous != null && next == null) {
        _attempt++;
        state = const AsyncData(null);
      }
    });

    return const AsyncData(null);
  }

  Future<bool> signIn(String email) async {
    if (state.isLoading) {
      return false;
    }

    final normalized = email.trim().toLowerCase();
    final recognized = DemoPersona.values.any(
      (persona) => persona.email == normalized,
    );

    if (!recognized) {
      state = AsyncError(
        ValidationFailure(
          errors: const {},
          detail: 'Enter a recognised demo email.',
        ),
        StackTrace.current,
      );
      return false;
    }

    if (!ref.read(useApiRepositoriesProvider)) {
      final accepted = ref
          .read(demoSessionProvider.notifier)
          .signIn(normalized);

      state = const AsyncData(null);
      return accepted;
    }

    if (ref.read(appConfigProvider).flavor != AppFlavor.dev) {
      state = AsyncError(
        const ForbiddenFailure(
          detail: 'Development sign-in is available in dev builds only.',
        ),
        StackTrace.current,
      );
      return false;
    }

    const password = String.fromEnvironment('DEV_SEED_PASSWORD');

    if (password.isEmpty) {
      state = AsyncError(
        const RuleFailure(detail: 'Development sign-in is not configured.'),
        StackTrace.current,
      );
      return false;
    }

    final attempt = ++_attempt;
    state = const AsyncLoading();

    final result = await ref
        .read(apiAuthRepositoryProvider)
        .signIn(email: normalized, password: password);

    if (!ref.mounted || attempt != _attempt) {
      return false;
    }

    switch (result) {
      case Ok<AccessToken>(:final value):
        ref
            .read(accessTokenStoreProvider.notifier)
            .save(
              value: value.value,
              expiresAtUtc: value.expiresAtUtc,
              userId: value.userId,
            );

        ref.read(demoSessionProvider.notifier).signIn(normalized);
        state = const AsyncData(null);
        return true;

      case Err<AccessToken>(:final failure):
        state = AsyncError(failure, StackTrace.current);
        return false;
    }
  }

  void clearError() {
    if (!state.isLoading) {
      state = const AsyncData(null);
    }
  }
}
