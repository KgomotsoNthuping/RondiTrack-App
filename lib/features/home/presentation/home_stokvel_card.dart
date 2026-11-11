import 'package:flutter/material.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

class HomeStokvelCard extends StatelessWidget {
  const new({required this.entry, super.key});

  final HomeEntry entry;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF020618);
    final muted = dark ? const Color(0xFFCAD5E2) : const Color(0xFF45556C);
    final border = dark ? const Color(0xFF314158) : const Color(0xFFE2E8F0);
    final walletFill = dark ? const Color(0xFFBBF451) : const Color(0xFFECFCCA);
    final walletInk = dark ? const Color(0xFF192E03) : const Color(0xFF35530E);

    final cycle = entry.currentCycleNumber;
    final status = entry.cycleStatus ?? CycleStatus.unknown;
    final due = entry.cycleDueDate;
    final paid = entry.paidThisCycle;
    final owed = entry.stillOwed;
    final payout = entry.nextPayoutDateUtc;
    final isOpen = cycle != null && status == CycleStatus.open;
    final arrears = 'Arrears ${entry.arrears.formatRand()}';

    final (badgeFill, badgeInk) = switch (status) {
      CycleStatus.open => (
        dark ? const Color(0xFFBBF451) : const Color(0xFFD8F999),
        const Color(0xFF192E03),
      ),
      CycleStatus.closed => (
        dark ? const Color(0xFF314158) : const Color(0xFFE2E8F0),
        dark ? Colors.white : const Color(0xFF0F172B),
      ),
      CycleStatus.paidOut => (
        dark ? const Color(0xFF8EC5FF) : const Color(0xFFDBEAFE),
        const Color(0xFF162456),
      ),
      CycleStatus.unknown => (
        dark ? const Color(0xFF314158) : const Color(0xFFF1F5F9),
        dark ? Colors.white : const Color(0xFF0F172B),
      ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                      color: walletFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: walletInk,
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
                    _badge(status.label, badgeFill, badgeInk),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  due == null ? 'No due date set' : 'Due ${_dateLabel(due)}',
                ),
                const SizedBox(height: 12),
              ],
              if (isOpen && paid != null && owed != null)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final tileWidth = width >= 280 ? (width - 12) / 2 : width;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _AmountTile(
                            label: 'Paid this cycle',
                            amount: paid.formatRand(),
                            fill: dark
                                ? const Color(0x66192E03)
                                : const Color(0xFFF7FEE7),
                            ink: dark
                                ? const Color(0xFFD8F999)
                                : const Color(0xFF35530E),
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _AmountTile(
                            label: 'Still owed',
                            amount: owed.formatRand(),
                            fill: dark
                                ? const Color(0xFF1D293D)
                                : const Color(0xFFF8FAFC),
                            ink: ink,
                          ),
                        ),
                      ],
                    );
                  },
                )
              else
                Text(isOpen ? 'Payment details unavailable' : 'No open cycle'),
              if (isOpen && owed?.value == 0) ...[
                const SizedBox(height: 12),
                _badge(
                  'All paid up for this cycle',
                  walletFill,
                  const Color(0xFF192E03),
                ),
              ],
              const SizedBox(height: 12),
              if (entry.arrears.value > 0)
                _badge(
                  arrears,
                  dark ? const Color(0xFFFFA2A2) : const Color(0xFFFFE2E2),
                  const Color(0xFF460809),
                )
              else
                Text(arrears),
              Divider(height: 32, color: border),
              Text(
                'Next payout',
                style: TextStyle(color: ink, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                payout == null ? 'No payout scheduled' : _payoutLabel(payout),
              ),
            ],
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
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _badge(String label, Color fill, Color ink) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label,
        style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

String _dateLabel(CalendarDate date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _payoutLabel(DateTime instant) {
  final date = instant.toUtc().add(const Duration(hours: 2));
  return _dateLabel((year: date.year, month: date.month, day: date.day));
}
