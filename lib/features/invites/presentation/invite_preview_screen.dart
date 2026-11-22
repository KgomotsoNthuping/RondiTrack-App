import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/session/account_key.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/core/widgets/failure_notice.dart';
import 'package:ronditrack/features/invites/application/family_invite.dart';
import 'package:ronditrack/features/invites/application/invite_provider.dart';
import 'package:ronditrack/features/invites/domain/invite_repository.dart';

class InvitePreviewScreen extends ConsumerWidget {
  const InvitePreviewScreen({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(useApiRepositoriesProvider)
        ? _ApiInviteScreen(
            key: ValueKey((code, ref.watch(accountKeyProvider))),
            code: code,
          )
        : _FixtureInviteScreen(code: code);
  }
}

class _ApiInviteScreen extends ConsumerStatefulWidget {
  const _ApiInviteScreen({required this.code, super.key});

  final String code;

  @override
  ConsumerState<_ApiInviteScreen> createState() => _ApiInviteScreenState();
}

class _ApiInviteScreenState extends ConsumerState<_ApiInviteScreen> {
  String? _opening;

  @override
  Widget build(BuildContext context) {
    final provider = joinInviteProvider(widget.code);
    final result = ref.watch(provider);

    return result.when(
      loading: () => _invitePage([
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        const Text('Joining stokvel…'),
      ]),
      error: (error, _) {
        final failure = error is Failure ? error : const ServerFailure();

        return _invitePage([
          FailureNotice(
            state: ScreenFailure<Object?>(
              failure is NotFoundFailure
                  ? 'This invite is not valid. Check the link or ask for a new one.'
                  : failure.message,
              correlationId: failure.correlationId,
              canRetry:
                  failure is OfflineFailure ||
                  failure is ServerFailure ||
                  failure is RateLimitedFailure,
              retryLabel: 'Try again',
            ),
            onRetry: () => ref.invalidate(provider),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => const HomeRoute().go(context),
            child: const Text('Go home'),
          ),
        ]);
      },
      data: (JoinedInvite destination) {
        if (_opening != destination.stokvelId) {
          _opening = destination.stokvelId;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              StokvelDetailRoute(id: destination.stokvelId).go(context);
            }
          });
        }

        return _invitePage([
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Text('Opening ${destination.name}…'),
        ]);
      },
    );
  }
}

class _FixtureInviteScreen extends ConsumerWidget {
  const _FixtureInviteScreen({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (code != familyInviteCode) {
      return _invitePage([const Text('Not found')]);
    }

    final persona = ref.watch(demoSessionProvider);

    if (persona == null) {
      return _invitePage([const Center(child: CircularProgressIndicator())]);
    }

    final alreadyMember =
        persona != DemoPersona.naledi || ref.watch(familyInviteProvider);

    return _invitePage([
      Text(
        familyInviteStokvelName,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(
        alreadyMember
            ? 'You already belong to this stokvel.'
            : 'Join this stokvel as a member.',
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () {
          final accepted = ref.read(familyInviteProvider.notifier).accept(code);

          if (accepted) {
            const StokvelDetailRoute(id: familyInviteStokvelId).go(context);
          }
        },
        child: Text(alreadyMember ? 'Open stokvel' : 'Join stokvel'),
      ),
    ]);
  }
}

Widget _invitePage(List<Widget> children) {
  return Scaffold(
    appBar: AppBar(title: const Text('Stokvel invite')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}
