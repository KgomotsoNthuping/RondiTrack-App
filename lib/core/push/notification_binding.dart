import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/experimental/scope.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/offline/offline_enabled.dart';
import 'package:ronditrack/core/push/notification_permission.dart';
import 'package:ronditrack/core/push/notification_providers.dart';
import 'package:ronditrack/core/push/push_target.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_workflow_provider.dart';

@Dependencies([homeRepository, Home, stokvelDetail])
class NotificationBinding extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationBinding> createState() =>
      _NotificationBindingState();
}

class _NotificationBindingState extends ConsumerState<NotificationBinding> {
  StreamSubscription<PushTarget>? _updates;
  DialogRoute<bool>? _dialog;

  bool _asking = false;

  @override
  void initState() {
    super.initState();

    final runtime = ref.read(pushRuntimeProvider);

    if (runtime.enabled && ref.read(useApiRepositoriesProvider)) {
      _updates = runtime.updates.listen(
        (target) => unawaited(_refresh(target)),
      );
    }
  }

  bool _current(SessionCoordinator coordinator, AuthSignedIn account) {
    final next = coordinator.state;

    return mounted &&
        next is AuthSignedIn &&
        next.identity.userId == account.identity.userId &&
        next.sessionId == account.sessionId &&
        coordinator.epoch == account.sessionId;
  }

  Future<void> _refresh(PushTarget target) async {
    if (!mounted) {
      return;
    }

    final coordinator = ref.read(sessionCoordinatorProvider);
    final state = coordinator.state;

    if (state is! AuthSignedIn || !_current(coordinator, state)) {
      return;
    }

    try {
      if (ref.read(offlineEnabledProvider)) {
        final account = (
          userId: state.identity.userId,
          sessionId: state.sessionId,
        );

        await ref
            .read(stokvelWorkflowProvider(account))
            .latestCycle(target.stokvelId, target.cycleId);

        if (_current(coordinator, state)) {
          ref.read(pushRevisionsProvider.notifier).changed((
            userId: account.userId,
            sessionId: account.sessionId,
            stokvelId: target.stokvelId,
            cycleId: target.cycleId,
          ));
        }
      } else {
        final provider = stokvelDetailProvider(
          target.stokvelId,
          cycleId: target.cycleId,
        );

        ref.invalidate(provider);

        final keep = ref.listenManual(provider, (_, _) {});

        try {
          await ref.read(provider.future);
        } finally {
          keep.close();
        }
      }
    } on Object {}
  }

  Future<void> _afterPayment() async {
    if (!mounted || _asking) {
      return;
    }

    final coordinator = ref.read(sessionCoordinatorProvider);
    final state = coordinator.state;

    if (state is! AuthSignedIn || !_current(coordinator, state)) {
      return;
    }

    _asking = true;

    try {
      final outcome = await ref
          .read(notificationPermissionProvider)
          .afterPayment(
            isCurrent: () => _current(coordinator, state),
            explain: () async {
              if (!_current(coordinator, state)) {
                return false;
              }

              final navigator = ref.read(rootNavigatorKeyProvider).currentState;

              if (navigator == null) {
                return false;
              }

              final route = DialogRoute<bool>(
                context: navigator.context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Get payment updates?'),
                  content: const Text(
                    'Would you like a notification when your treasurer '
                    'confirms a payment? You can still check its status '
                    'in the app.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Not now'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Yes, notify me'),
                    ),
                  ],
                ),
              );

              _dialog = route;

              try {
                return await navigator.push(route) == true;
              } finally {
                if (identical(_dialog, route)) {
                  _dialog = null;
                }
              }
            },
          );

      if (!mounted) {
        return;
      }

      if (outcome == PermissionOutcome.denied && _current(coordinator, state)) {
        final runtime = ref.read(pushRuntimeProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Notifications are off. Your payment status is still '
              'in the app.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                unawaited(
                  runtime.notifications.openSettings().catchError(
                    (Object _) {},
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      _asking = false;
    }
  }

  void _closeDialog() {
    final dialog = _dialog;
    _dialog = null;

    if (dialog != null) {
      scheduleMicrotask(() {
        final navigator = dialog.navigator;

        if (navigator != null && navigator.mounted) {
          navigator.removeRoute(dialog, false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(pushRuntimeProvider);

    if (runtime.enabled && ref.watch(useApiRepositoriesProvider)) {
      ref.listen(paymentRecordedProvider, (_, _) {
        unawaited(_afterPayment());
      });

      ref.listen(sessionStateProvider, (previous, next) {
        if (previous is AuthSignedIn &&
            (next is! AuthSignedIn ||
                next.identity.userId != previous.identity.userId ||
                next.sessionId != previous.sessionId)) {
          _closeDialog();
        }
      });
    }

    return widget.child;
  }

  @override
  void dispose() {
    unawaited(_updates?.cancel());
    _closeDialog();
    super.dispose();
  }
}
