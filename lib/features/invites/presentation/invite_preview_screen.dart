import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/features/invites/application/family_invite.dart';

class InvitePreviewScreen extends ConsumerWidget {
  const new({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (code != familyInviteCode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stokvel invite')),
        body: const Center(child: Text('Not found')),
      );
    }

    final persona = ref.watch(demoSessionProvider);
    if (persona == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final nalediJoined = ref.watch(familyInviteProvider);
    final alreadyMember = persona != DemoPersona.naledi || nalediJoined;

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
                children: [
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
                      final accepted = ref
                          .read(familyInviteProvider.notifier)
                          .accept(code);

                      if (accepted) {
                        const StokvelDetailRoute(
                          id: familyInviteStokvelId,
                        ).go(context);
                      }
                    },
                    child: Text(
                      alreadyMember ? 'Open stokvel' : 'Join stokvel',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}