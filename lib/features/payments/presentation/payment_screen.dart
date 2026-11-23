import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/offline/application/offline_account_provider.dart';
import 'package:ronditrack/features/offline/presentation/cache_view.dart';
import 'package:ronditrack/features/payments/application/payment_provider.dart';
import 'package:ronditrack/features/payments/domain/pending_payment.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_actions.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({
    required this.stokvelId,
    required this.cycleId,
    super.key,
  });

  final String stokvelId;
  final String cycleId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();

  bool _seeded = false;
  bool _submitting = false;
  String? _message;
  String? _editedAfterNotice;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionStateProvider);

    if (state is! AuthSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final account = (userId: state.identity.userId, sessionId: state.sessionId);

    final worker = ref.watch(paymentWorkerProvider(account));

    final controller = ref.watch(
      cachedStokvelProvider((account: account, stokvelId: widget.stokvelId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay contribution'),
        leading: BackButton(onPressed: () => context.go(_cycleAddress())),
      ),
      body: CacheView<Stokvel>(
        controller: controller,
        builder: (context, stokvel) {
          if (!_seeded) {
            _seeded = true;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _amount.text.isEmpty) {
                _amount.text = stokvel.monthlyContribution.formatRand();
              }
            });
          }

          return StreamBuilder<List<PendingPayment>>(
            stream: worker.pending,
            builder: (context, pendingSnapshot) {
              final pending = _matchingPayment(
                pendingSnapshot.data ?? const [],
                widget.stokvelId,
                widget.cycleId,
              );

              return StreamBuilder<List<PaymentNotice>>(
                stream: worker.notices,
                builder: (context, noticeSnapshot) {
                  final notice = _matchingNotice(
                    noticeSnapshot.data ?? const [],
                    widget.stokvelId,
                    widget.cycleId,
                  );

                  final showErrors =
                      pending == null &&
                      notice?.kind == PaymentNoticeKind.refused &&
                      _editedAfterNotice != notice?.key;

                  final errors = showErrors
                      ? notice!.errors
                      : const <String, List<String>>{};

                  final cycle = stokvel.currentCycle;
                  final correctCycle = cycle?.id == widget.cycleId;

                  ContributionStatus? ownStatus;

                  for (final contribution in stokvel.contributions) {
                    if (contribution.userId == state.identity.userId &&
                        contribution.cycleId == widget.cycleId) {
                      ownStatus = contribution.status;
                      break;
                    }
                  }

                  final actions = availableActions((
                    stokvel.membership.role,
                    correctCycle ? cycle?.status : null,
                    ownStatus,
                  ));

                  final canPay =
                      correctCycle &&
                      actions.contains(StokvelAction.pay) &&
                      state.failure is! UnauthorizedFailure;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            stokvel.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          if (!correctCycle)
                            const Text(
                              'This is no longer the current cycle. '
                              'Existing pending attempts are shown below.',
                            ),
                          if (pending != null) ...[
                            PaymentPendingCard(
                              payment: pending,
                              onRetry: worker.drain,
                              onReview: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text(
                                      'Have you checked this payment?',
                                    ),
                                    content: const Text(
                                      'Check whether it was recorded '
                                      'before allowing another attempt.',
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
                                  await worker.acknowledgeExpired(pending.key);

                                  await controller.refresh();
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (notice != null && pending == null) ...[
                            PaymentNoticeCard(notice: notice),
                            const SizedBox(height: 12),
                          ],
                          Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  initialValue: state.identity.email,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'Member account',
                                    errorText: _fieldError(errors, 'userId'),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: const ValueKey('payment-amount'),
                                  controller: _amount,
                                  enabled:
                                      pending == null && !_submitting && canPay,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: 'Amount in rands',
                                    errorText: _fieldError(
                                      errors,
                                      'amountInCents',
                                    ),
                                  ),
                                  onChanged: (_) {
                                    setState(() {
                                      _editedAfterNotice = notice?.key;
                                      _message = null;
                                    });
                                  },
                                  validator: (value) {
                                    final parsed = parseRand(value ?? '');

                                    return switch (parsed) {
                                      InvalidRand(:final reason) => reason,
                                      ParsedRand(:final cents)
                                          when cents.value <= 0 =>
                                        'Enter an amount greater than zero.',
                                      ParsedRand() => null,
                                    };
                                  },
                                ),
                                const SizedBox(height: 16),
                                if (_message != null) ...[
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(_message!),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                FilledButton(
                                  key: const ValueKey('payment-submit'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  onPressed:
                                      pending != null || _submitting || !canPay
                                      ? null
                                      : () async {
                                          if (!_form.currentState!.validate()) {
                                            return;
                                          }

                                          final parsed = parseRand(
                                            _amount.text,
                                          );

                                          if (parsed is! ParsedRand) {
                                            return;
                                          }

                                          setState(() {
                                            _submitting = true;
                                            _message = null;
                                          });

                                          try {
                                            await worker.enqueue(
                                              stokvelId: widget.stokvelId,
                                              cycleId: widget.cycleId,
                                              amount: parsed.cents,
                                            );
                                          } on Object catch (error) {
                                            if (mounted) {
                                              setState(() {
                                                _message = error.toString();
                                              });
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() {
                                                _submitting = false;
                                              });
                                            }
                                          }
                                        },
                                  child: Text(
                                    _submitting ? 'Saving payment…' : 'Pay',
                                  ),
                                ),
                                if (!canPay && pending == null) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'A new payment is not available '
                                    'for this cycle.',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _cycleAddress() {
    return Uri(
      pathSegments: [
        '',
        'stokvels',
        widget.stokvelId,
        'cycles',
        widget.cycleId,
      ],
    ).toString();
  }
}

class PaymentPendingCard extends StatelessWidget {
  const PaymentPendingCard({
    required this.payment,
    required this.onRetry,
    required this.onReview,
    super.key,
  });

  final PendingPayment payment;
  final Future<void> Function() onRetry;
  final Future<void> Function() onReview;

  @override
  Widget build(BuildContext context) {
    final message = switch (payment.phase) {
      PaymentPhase.pending => 'Pending. This payment has not been confirmed.',
      PaymentPhase.waiting =>
        'Waiting until ${payment.retryAtUtc?.toIso8601String()} '
            'before trying again.',
      PaymentPhase.expired =>
        'This attempt expired and will not be sent again. '
            'Check whether it was recorded before paying again.',
      PaymentPhase.clockMismatch =>
        'Check this device’s date and time before retrying.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(payment.amount.formatRand()),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 8),
            if (payment.phase == PaymentPhase.expired)
              TextButton(
                onPressed: onReview,
                child: const Text('I have checked this payment'),
              )
            else
              TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class PaymentNoticeCard extends StatelessWidget {
  const PaymentNoticeCard({required this.notice, super.key});

  final PaymentNotice notice;

  @override
  Widget build(BuildContext context) {
    final message = switch (notice.kind) {
      PaymentNoticeKind.paid => 'Paid',
      PaymentNoticeKind.refused => notice.detail ?? 'The payment was refused.',
      PaymentNoticeKind.expired =>
        'The attempt expired. Check before paying again.',
      PaymentNoticeKind.clockMismatch => 'Check this device’s date and time.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          liveRegion: true,
          child: Text('${notice.amount.formatRand()} · $message'),
        ),
      ),
    );
  }
}

PendingPayment? _matchingPayment(
  List<PendingPayment> values,
  String stokvelId,
  String cycleId,
) {
  for (final value in values) {
    if (value.stokvelId == stokvelId && value.cycleId == cycleId) {
      return value;
    }
  }

  return null;
}

PaymentNotice? _matchingNotice(
  List<PaymentNotice> values,
  String stokvelId,
  String cycleId,
) {
  for (final value in values) {
    if (value.stokvelId == stokvelId && value.cycleId == cycleId) {
      return value;
    }
  }

  return null;
}

String? _fieldError(Map<String, List<String>> errors, String field) {
  for (final entry in errors.entries) {
    if (entry.key.split('.').last.toLowerCase() == field.toLowerCase()) {
      return entry.value.join('\n');
    }
  }

  return null;
}
