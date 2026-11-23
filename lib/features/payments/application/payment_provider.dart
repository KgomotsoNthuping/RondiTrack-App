import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/offline/data/offline_database_provider.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/offline/application/offline_account_provider.dart';
import 'package:ronditrack/features/payments/application/payment_worker.dart';
import 'package:ronditrack/features/payments/data/payment_outbox.dart';
import 'package:ronditrack/features/payments/data/payment_sender.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_workflow_provider.dart';

final paymentOutboxProvider = Provider<PaymentOutbox>(
  (ref) => PaymentOutbox(ref.watch(offlineDatabaseProvider)),
  dependencies: [offlineDatabaseProvider],
);

final paymentWorkerProvider = Provider.autoDispose
    .family<PaymentWorker, OfflineAccountKey>(
      (ref, account) {
        final session = ref.watch(sessionCoordinatorProvider);
        final store = ref.watch(paymentOutboxProvider);
        final home = ref.watch(cachedHomeProvider(account));

        bool isCurrent() {
          final state = session.state;

          return state is AuthSignedIn &&
              state.identity.userId == account.userId &&
              state.sessionId == account.sessionId &&
              session.epoch == account.sessionId;
        }

        bool canSend() {
          final state = session.state;

          return isCurrent() &&
              state is AuthSignedIn &&
              state.failure is! UnauthorizedFailure;
        }

        final sender = PaymentSender(() => ref.read(apiDioProvider));
        final keepAlive = ref.keepAlive();

        final worker = PaymentWorker(
          store: store,
          userId: account.userId,
          send: sender.send,
          isCurrent: isCurrent,
          canSend: canSend,
          onResolved: (payment) async {
            if (isCurrent()) {
              await ref
                  .read(stokvelWorkflowProvider(account))
                  .refreshScreens(payment.stokvelId);
            }
          },
        );

        DateTime? lastHomeUpdate = home.cached?.updatedAtUtc;

        void observeHome() {
          final updated = home.cached?.updatedAtUtc;

          if (updated != null &&
              updated != lastHomeUpdate &&
              home.failure == null) {
            lastHomeUpdate = updated;
            unawaited(worker.drain());
          }
        }

        home.addListener(observeHome);

        ref.listen(sessionStateProvider, (previous, next) {
          if (!isCurrent()) {
            keepAlive.close();
            return;
          }

          if (next is AuthSignedIn &&
              next.currentAccessToken != null &&
              (previous is! AuthSignedIn ||
                  previous.currentAccessToken == null)) {
            unawaited(worker.drain());
          }
        });

        ref.onDispose(() {
          home.removeListener(observeHome);
          worker.dispose();
        });

        scheduleMicrotask(() {
          if (isCurrent()) {
            unawaited(worker.drain());
          }
        });

        return worker;
      },
      dependencies: [
        sessionCoordinatorProvider,
        sessionStateProvider,
        paymentOutboxProvider,
        cachedHomeProvider,
        stokvelWorkflowProvider,
        apiDioProvider,
      ],
    );