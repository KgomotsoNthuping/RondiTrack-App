import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/account_key.dart';
import 'package:ronditrack/features/invites/data/api_invite_repository.dart';
import 'package:ronditrack/features/invites/domain/invite_repository.dart';

part 'invite_provider.g.dart';

@Riverpod(keepAlive: true, dependencies: [accountKey])
InviteRepository inviteRepository(Ref ref) {
  requireAccount(ref);

  return ref.watch(apiInviteRepositoryProvider);
}

@Riverpod(
  keepAlive: true,
  dependencies: [accountKey, inviteRepository, MembershipRevision],
)
Future<JoinedInvite> joinInvite(Ref ref, String code) async {
  final account = requireAccount(ref);

  if (account == null) {
    throw const UnauthorizedFailure();
  }

  final repository = ref.watch(inviteRepositoryProvider);

  void checkAccount() {
    if (!ref.mounted || ref.read(accountKeyProvider) != account) {
      throw const UnauthorizedFailure();
    }
  }

  final preview = _unwrap(await repository.preview(code));

  checkAccount();

  JoinedInvite destination;

  if (preview.alreadyMember) {
    destination = JoinedInvite(
      stokvelId: preview.stokvelId,
      name: preview.name,
    );
  } else {
    final result = await repository.join(code);

    checkAccount();

    switch (result) {
      case Ok<JoinedInvite>(:final value):
        destination = value;

      case Err<JoinedInvite>(:final failure):
        if (failure is! ConflictFailure) {
          throw failure;
        }

        final current = _unwrap(await repository.preview(code));

        checkAccount();

        if (!current.alreadyMember) {
          throw failure;
        }

        destination = JoinedInvite(
          stokvelId: current.stokvelId,
          name: current.name,
        );
    }
  }

  checkAccount();

  ref.read(membershipRevisionProvider.notifier).changed();

  return destination;
}

T _unwrap<T>(Result<T> result) => switch (result) {
  Ok<T>(:final value) => value,
  Err<T>(:final failure) => throw failure,
};
