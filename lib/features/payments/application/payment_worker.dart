import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/offline/outbox_policy.dart';
import 'package:ronditrack/features/payments/data/payment_outbox.dart';
import 'package:ronditrack/features/payments/domain/pending_payment.dart';

final class PaymentWorker extends ChangeNotifier {
  PaymentWorker({
    required PaymentOutbox store,
    required this.userId,
    required Future<PaymentReply> Function(PendingPayment) send,
    required bool Function() isCurrent,
    required bool Function() canSend,
    required Future<void> Function(PendingPayment) onResolved,
    DateTime Function()? clock,
    OutboxPolicy? policy,
  }) : _store = store,
       _send = send,
       _isCurrent = isCurrent,
       _canSend = canSend,
       _onResolved = onResolved,
       _clock = clock ?? DateTime.now,
       _policy =
           policy ??
           OutboxPolicy(
             maximumAge: const Duration(hours: 24),
             serverRetention: const Duration(hours: 48),
           );

  final PaymentOutbox _store;
  final String userId;
  final Future<PaymentReply> Function(PendingPayment) _send;
  final bool Function() _isCurrent;
  final bool Function() _canSend;
  final Future<void> Function(PendingPayment) _onResolved;
  final DateTime Function() _clock;
  final OutboxPolicy _policy;

  Future<void>? _flight;
  Timer? _timer;
  Failure? _lastFailure;
  bool _again = false;
  bool _closed = false;
  bool _sending = false;

  bool get sending => _sending;

  Failure? get lastFailure => _lastFailure;

  Stream<List<PendingPayment>> get pending => _store.watch(userId);

  Stream<List<PaymentNotice>> get notices => _store.watchNotices(userId);

  Future<bool> hasPendingPayments() {
    return _store.hasPendingPayments();
  }

  Future<PendingPayment> enqueue({
    required String stokvelId,
    required String cycleId,
    required Cents amount,
  }) async {
    if (!_active || !_canSend()) {
      throw const UnauthorizedFailure();
    }

    final payment = await _store.enqueue(
      generation: _store.generation,
      userId: userId,
      stokvelId: stokvelId,
      cycleId: cycleId,
      amount: amount,
      createdAtUtc: _clock().toUtc(),
    );

    await drain();
    return payment;
  }

  Future<void> acknowledgeExpired(String key) async {
    if (!_active) {
      return;
    }

    await _store.acknowledgeExpired(
      generation: _store.generation,
      userId: userId,
      key: key,
    );
  }

  bool get _active => !_closed && _isCurrent();

  Future<void> drain() {
    if (!_active) {
      return Future<void>.value();
    }

    final pending = _flight;

    if (pending != null) {
      _again = true;
      return pending;
    }

    _timer?.cancel();
    _timer = null;

    late final Future<void> flight;

    flight = _run().whenComplete(() {
      if (identical(_flight, flight)) {
        _flight = null;
      }
    });

    _flight = flight;
    return flight;
  }

  Future<void> _run() async {
    try {
      do {
        _again = false;

        final generation = _store.generation;
        final payments = await _store.read(userId);

        for (final payment in payments) {
          if (!_active || generation != _store.generation) {
            return;
          }

          if (payment.phase == PaymentPhase.expired) {
            continue;
          }

          final now = _clock().toUtc();

          final age = _policy.assess(
            createdAtUtc: payment.createdAtUtc,
            nowUtc: now,
          );

          if (age == OutboxAge.expired) {
            await _store.requireReview(
              generation: generation,
              payment: payment,
              phase: PaymentPhase.expired,
              kind: PaymentNoticeKind.expired,
              nowUtc: now,
            );
            continue;
          }

          if (age == OutboxAge.clockMismatch) {
            if (payment.phase != PaymentPhase.clockMismatch) {
              await _store.requireReview(
                generation: generation,
                payment: payment,
                phase: PaymentPhase.clockMismatch,
                kind: PaymentNoticeKind.clockMismatch,
                nowUtc: now,
              );
            }

            continue;
          }

          final retryAt = payment.retryAtUtc;

          if (retryAt != null && now.isBefore(retryAt)) {
            continue;
          }

          if (!_canSend()) {
            continue;
          }

          _sending = true;
          _lastFailure = null;
          _notify();

          final reply = await _send(payment);

          if (!_active || generation != _store.generation) {
            return;
          }

          switch (reply) {
            case PaymentAccepted(:final contributionId):
              final saved = await _store.finish(
                generation: generation,
                payment: payment,
                kind: PaymentNoticeKind.paid,
                nowUtc: _clock().toUtc(),
                contributionId: contributionId,
              );

              if (saved && _active) {
                await _onResolved(payment);
              }

            case PaymentRefused(:final failure):
              final saved = await _store.finish(
                generation: generation,
                payment: payment,
                kind: PaymentNoticeKind.refused,
                nowUtc: _clock().toUtc(),
                failure: failure,
              );

              if (saved && _active) {
                await _onResolved(payment);
              }

            case PaymentWaiting(:final retryAtUtc):
              await _store.hold(
                generation: generation,
                payment: payment,
                phase: PaymentPhase.waiting,
                retryAtUtc: retryAtUtc,
              );

            case PaymentUnanswered(:final failure):
              _lastFailure = failure;

              await _store.hold(
                generation: generation,
                payment: payment,
                phase: PaymentPhase.pending,
              );
          }

          _sending = false;
          _notify();
        }
      } while (_again && _active);
    } on Object {
      _lastFailure = const ServerFailure();
    } finally {
      _sending = false;
      _notify();

      if (_active) {
        await _scheduleWake();
      }
    }
  }

  Future<void> _scheduleWake() async {
    try {
      final payments = await _store.read(userId);

      if (!_active) {
        return;
      }

      DateTime? nextWake;

      for (final payment in payments) {
        if (payment.phase == PaymentPhase.expired ||
            payment.phase == PaymentPhase.clockMismatch) {
          continue;
        }

        var deadline = payment.createdAtUtc.add(_policy.maximumAge);
        final retry = payment.retryAtUtc;

        if (retry != null && retry.isBefore(deadline)) {
          deadline = retry;
        }

        if (nextWake == null || deadline.isBefore(nextWake)) {
          nextWake = deadline;
        }
      }

      if (nextWake == null) {
        return;
      }

      final delay = nextWake.difference(_clock().toUtc());

      _timer?.cancel();
      _timer = Timer(
        delay <= Duration.zero ? const Duration(seconds: 1) : delay,
        () => unawaited(drain()),
      );
    } on Object {
      _lastFailure = const ServerFailure();
      _notify();
    }
  }

  void _notify() {
    if (!_closed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    super.dispose();
  }
}
