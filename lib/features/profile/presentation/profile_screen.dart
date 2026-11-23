import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/offline/offline_enabled.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/session/session_coordinator.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/payments/application/payment_provider.dart';
import 'package:ronditrack/features/payments/domain/pending_payment.dart';
import 'package:ronditrack/features/payments/presentation/payment_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(demoSessionProvider);

    if (member == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final offlineEnabled = ref.watch(offlineEnabledProvider);
    final state = ref.watch(sessionStateProvider);

    final account = state is AuthSignedIn
        ? (userId: state.identity.userId, sessionId: state.sessionId)
        : null;

    final worker = offlineEnabled && account != null
        ? ref.watch(paymentWorkerProvider(account))
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  member.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(member.email),
                const SizedBox(height: 20),
                if (state is AuthSignedIn &&
                    (state.isOffline ||
                        state.failure is UnauthorizedFailure)) ...[
                  const Text(
                    'Your saved account is open. '
                    'Sign in again to restore server access.',
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: () async {
                        await showDialog<void>(
                          context: context,
                          builder: (_) =>
                              _SignInAgainDialog(email: member.email),
                        );
                      },
                      child: const Text('Sign in again'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (worker != null) ...[
                  StreamBuilder<List<PendingPayment>>(
                    stream: worker.pending,
                    builder: (context, snapshot) {
                      final payments = snapshot.data ?? const [];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final payment in payments)
                            PaymentPendingCard(
                              payment: payment,
                              onRetry: worker.drain,
                              onReview: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text(
                                      'Have you checked '
                                      'this payment?',
                                    ),
                                    content: const Text(
                                      'Confirm whether it '
                                      'was recorded before '
                                      'allowing another attempt.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('I have checked'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  await worker.acknowledgeExpired(payment.key);
                                }
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  StreamBuilder<List<PaymentNotice>>(
                    stream: worker.notices,
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          for (final notice
                              in snapshot.data ?? const <PaymentNotice>[])
                            PaymentNoticeCard(notice: notice),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () async {
                      var discard = false;

                      if (worker != null && await worker.hasPendingPayments()) {
                        if (!context.mounted) {
                          return;
                        }

                        discard =
                            await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Discard pending payments?'),
                                content: const Text(
                                  'Signing out removes saved '
                                  'payment attempts. Check their '
                                  'status before paying again.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Keep them'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Discard and sign out'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;

                        if (!discard) {
                          return;
                        }
                      }

                      if (!context.mounted) {
                        return;
                      }

                      if (ref.read(useApiRepositoriesProvider)) {
                        final result = await ref
                            .read(sessionCoordinatorProvider)
                            .signOut(discardPendingPayments: discard);

                        if (!context.mounted) {
                          return;
                        }

                        if (result case Err<void>(:final failure)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(failure.message)),
                          );
                          return;
                        }
                      } else {
                        ref.read(demoSessionProvider.notifier).signOut();
                      }

                      if (context.mounted) {
                        const SignInRoute().go(context);
                      }
                    },
                    child: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInAgainDialog extends ConsumerStatefulWidget {
  const new({required this.email});

  final String email;

  @override
  ConsumerState<_SignInAgainDialog> createState() => _SignInAgainDialogState();
}

class _SignInAgainDialogState extends ConsumerState<_SignInAgainDialog> {
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign in again'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.email),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(_error!)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  if (_password.text.isEmpty) {
                    setState(() {
                      _error = 'Enter your password.';
                    });
                    return;
                  }

                  setState(() {
                    _busy = true;
                    _error = null;
                  });

                  final result = await ref
                      .read(sessionCoordinatorProvider)
                      .reauthenticate(
                        email: widget.email,
                        password: _password.text,
                      );

                  if (!mounted) {
                    return;
                  }

                  switch (result) {
                    case Ok<void>():
                      Navigator.pop(context);
                    case Err<void>(:final failure):
                      setState(() {
                        _busy = false;
                        _error = failure is UnauthorizedFailure
                            ? 'The email and password do not match.'
                            : failure.message;
                      });
                  }
                },
          child: Text(_busy ? 'Signing in…' : 'Sign in'),
        ),
      ],
    );
  }
}
