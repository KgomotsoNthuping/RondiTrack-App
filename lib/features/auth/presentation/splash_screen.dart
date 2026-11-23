import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/auth/presentation/auth_form.dart';

class SplashScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStateProvider);
    final failure = session is AuthRestoring ? session.failure : null;

    return AuthPage(
      title: 'RondiTrack',
      subtitle: 'Restoring your session',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure == null) ...[
            const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Restoring session',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Checking your saved session…',
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              failure is OfflineFailure
                  ? 'You are offline. Your saved session is still on this device.'
                  : 'We could not restore your session yet.',
            ),
            const SizedBox(height: 16),
            AuthFailureNotice(failure: failure),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                unawaited(ref.read(sessionCoordinatorProvider).restore());
              },
              child: const Text('Try again'),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              unawaited(ref.read(sessionCoordinatorProvider).signOut());
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
