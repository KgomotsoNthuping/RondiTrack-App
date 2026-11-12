import 'package:flutter/material.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/theme/ronditrack_tokens.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_status_badge.dart';

class HomeStokvelCard extends StatelessWidget {
  const new({required this.entry, required this.onTap, super.key});

  final HomeEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RondiTrackTokens.of(context);
    final ink = tokens[RondiTrackToken.cardText].foreground;
    final muted = tokens[RondiTrackToken.cardMuted].foreground;
    final wallet = tokens[RondiTrackToken.wallet];
    final paidAmount = tokens[RondiTrackToken.paidAmount];
    final owedAmount = tokens[RondiTrackToken.owedAmount];
    final border = Theme.of(context).colorScheme.outlineVariant;

    final cycle = entry.currentCycleNumber;
    final status = entry.cycleStatus ?? CycleStatus.unknown;
    final due = entry.cycleDueDate;
    final paid = entry.paidThisCycle;
    final owed = entry.stillOwed;
    final payout = entry.nextPayoutDateUtc;
    final isOpen = cycle != null && status == CycleStatus.open;
    final arrears = 'Arrears ${entry.arrears.formatRand()}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: muted, fontSize: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: wallet.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: wallet.foreground,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            style: TextStyle(
                              color: ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(entry.membership.role.label),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(height: 32, color: border),
                if (cycle != null) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Cycle $cycle',
                        style: TextStyle(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      CycleStatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    due == null
                        ? 'No due date set'
                        : 'Due ${formatCalendarDate(due)}',
                  ),
                  const SizedBox(height: 12),
                ],
                if (isOpen && paid != null && owed != null)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const double gap = 12;
                      final textScaler = MediaQuery.textScalerOf(context);
                      final scale =
                          textScaler.scale(_AmountTile.amountFontSize) /
                          _AmountTile.amountFontSize;
                      final minimumTileWidth = 134 * scale;
                      final width = constraints.maxWidth;
                      final tileWidth = width >= 2 * minimumTileWidth + gap
                          ? (width - gap) / 2
                          : width;

                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          SizedBox(
                            width: tileWidth,
                            child: _AmountTile(
                              label: 'Paid this cycle',
                              amount: paid.formatRand(),
                              fill: paidAmount.background,
                              ink: paidAmount.foreground,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _AmountTile(
                              label: 'Still owed',
                              amount: owed.formatRand(),
                              fill: owedAmount.background,
                              ink: owedAmount.foreground,
                            ),
                          ),
                        ],
                      );
                    },
                  )
                else
                  Text(
                    isOpen ? 'Payment details unavailable' : 'No open cycle',
                  ),
                if (isOpen && owed?.value == 0) ...[
                  const SizedBox(height: 12),
                  const StokvelBadge(
                    label: 'All paid up for this cycle',
                    token: RondiTrackToken.paidUp,
                  ),
                ],
                const SizedBox(height: 12),
                if (entry.arrears.value > 0)
                  StokvelBadge(label: arrears, token: RondiTrackToken.arrears)
                else
                  Text(arrears),
                Divider(height: 32, color: border),
                Text(
                  'Next payout',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  payout == null
                      ? 'No payout scheduled'
                      : formatJohannesburgDate(payout),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const new({
    required this.label,
    required this.amount,
    required this.fill,
    required this.ink,
  });

  static const double amountFontSize = 20;

  final String label;
  final String amount;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(
                color: ink,
                fontSize: amountFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}