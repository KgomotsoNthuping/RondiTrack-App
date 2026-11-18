import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/core/theme/ronditrack_tokens.dart';
import 'package:ronditrack/core/widgets/failure_notice.dart';
import 'package:ronditrack/features/payouts/application/payout_provider.dart';
import 'package:ronditrack/features/payouts/domain/payout_order.dart';
import 'package:ronditrack/features/payouts/presentation/payout_status_badge.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvels_screen.dart';

class PayoutsScreen extends ConsumerWidget {
  const new({required this.stokvelId, required this.cycleId, super.key});

  final String stokvelId;
  final String cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = payoutOrderProvider((
      stokvelId: stokvelId,
      cycleId: cycleId,
    ));

    final view = payoutOrderViewState(ref.watch(provider));
    final detail = ref.watch(stokvelDetailProvider(stokvelId));
    final stokvel = detail.isLoading ? null : detail.asData?.value?.stokvel;

    final canReview =
        stokvel?.currentCycle?.id == cycleId &&
        stokvel?.membership.role == StokvelRole.treasurer;

    final children = switch (view) {
      ScreenLoading<PayoutOrder>() => const <Widget>[
        Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Loading payout order',
          ),
        ),
      ],
      ScreenEmpty<PayoutOrder>() => const <Widget>[
        Text('No payout order yet.'),
      ],
      final ScreenFailure<PayoutOrder> failure => <Widget>[
        FailureNotice(state: failure, onRetry: () => ref.invalidate(provider)),
      ],
      ScreenData<PayoutOrder>(:final value) => <Widget>[
        for (final entry in value.entries)
          _PayoutEntryCard(entry: entry, canReview: canReview),
      ],
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payouts', style: TextStyle(fontSize: 18)),
      ),
      body: StokvelLayout(
        selectedStokvelId: stokvelId,
        detail: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                primary: false,
                padding: const EdgeInsets.all(20),
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayoutEntryCard extends StatelessWidget {
  const new({required this.entry, required this.canReview});

  final PayoutOrderEntry entry;
  final bool canReview;

  @override
  Widget build(BuildContext context) {
    final ink = RondiTrackTokens.of(
      context,
    )[RondiTrackToken.cardText].foreground;

    final paidAt = entry.paidAtUtc;
    final amount = entry.amount.formatRand();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: ink),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.position}. ${entry.memberName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(amount),
              const SizedBox(height: 8),
              PayoutStatusBadge(status: entry.status),
              if (paidAt != null) ...[
                const SizedBox(height: 8),
                Text(formatJohannesburgDate(paidAt, includeTime: true)),
              ],
              if (canReview && entry.status == PayoutStatus.next) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    await showDialog<void>(
                      context: context,
                      useRootNavigator: false,
                      builder: (dialogContext) => AlertDialog(
                        scrollable: true,
                        title: const Text('Review payout'),
                        content: Text('${entry.memberName}\n$amount'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Review payout'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
