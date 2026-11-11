import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_actions.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_status_badge.dart';

/// Shows the selected stokvel and lets the member switch stokvels.
class StokvelDetailScreen extends ConsumerStatefulWidget {
  /// Opens detail at [initialStokvelId].
  const new({
    required this.initialStokvelId,
    required this.stokvelNames,
    super.key,
  });

  /// The stokvel selected from Home.
  final String initialStokvelId;

  /// The IDs and names of this member's stokvels.
  final Map<String, String> stokvelNames;

  @override
  ConsumerState<StokvelDetailScreen> createState() => _StokvelDetailScreenState();
}

class _StokvelDetailScreenState extends ConsumerState<StokvelDetailScreen> {
  late String _selectedId = widget.initialStokvelId;

  @override
  Widget build(BuildContext context) {
    final name = widget.stokvelNames[_selectedId] ?? 'Stokvel details';
    final provider = stokvelDetailProvider(_selectedId);
    final view = stokvelDetailViewState(ref.watch(provider));

    final content = switch (view) {
      ScreenLoading<StokvelDetail>() => [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 12),
        Text('Loading $name', textAlign: TextAlign.center),
      ],
      ScreenEmpty<StokvelDetail>() => const [
        Text('No cycle or contributions yet.'),
        SizedBox(height: 8),
        Text('Check again after your treasurer opens a cycle.'),
      ],
      ScreenFailure<StokvelDetail>(:final message) => [
        Text(message),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => ref.invalidate(provider),
            child: const Text('Retry'),
          ),
        ),
      ],
      ScreenData<StokvelDetail>(:final value) => _detailContent(context, value),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          if (widget.stokvelNames.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Switch stokvel',
              initialValue: _selectedId,
              icon: const Icon(Icons.swap_horiz),
              onSelected: (id) {
                setState(() {
                  _selectedId = id;
                });
              },
              itemBuilder: (context) => [
                for (final stokvel in widget.stokvelNames.entries)
                  PopupMenuItem(
                    value: stokvel.key,
                    child: Text(stokvel.value),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: ValueKey(_selectedId),
              padding: const EdgeInsets.all(20),
              children: content,
            ),
          ),
        ),
      ),
    );
  }
}

List<Widget> _detailContent(BuildContext context, StokvelDetail detail) {
  final stokvel = detail.stokvel;
  final cycle = stokvel.currentCycle;
  final due = cycle?.dueDate;
  final rules = stokvel.rules;
  final colors = Theme.of(context).colorScheme;

  return [
    _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stokvel.membership.role.label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text('${stokvel.monthlyContribution.formatRand()} per month'),
          Text(
            'Members ${stokvel.memberCount} · '
            'Period ${stokvel.currentPeriod} of ${stokvel.totalPeriods}',
          ),
          const Divider(height: 24),
          if (cycle != null) ...[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Cycle ${cycle.number}'),
                CycleStatusBadge(status: cycle.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(due == null ? 'No due date set' : 'Due ${formatCalendarDate(due)}'),
            Text('Target ${cycle.targetAmount.formatRand()}'),
            Text('Collected ${cycle.totalCollected.formatRand()}'),
            Text('Outstanding ${cycle.amountOutstanding.formatRand()}'),
          ] else
            const Text('No current cycle'),
          if (detail.actions.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('Available actions'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final action in detail.actions)
                  Chip(
                    label: Text(_actionLabel(action)),
                    labelStyle: TextStyle(color: colors.onPrimary),
                    backgroundColor: colors.primary,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
          if (rules != null && rules.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('Rules'),
            Text(rules),
          ],
        ],
      ),
    ),
    Text('Contributions', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    if (stokvel.contributions.isEmpty) const Text('No contributions yet.'),
    for (final contribution in stokvel.contributions)
      _ContributionCard(contribution: contribution),
  ];
}

class _ContributionCard extends StatelessWidget {
  const new({required this.contribution});

  final Contribution contribution;

  @override
  Widget build(BuildContext context) {
    final paidAt = contribution.paidAtUtc;
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contribution.memberName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                contribution.amount.formatRand(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              ContributionStatusBadge(status: contribution.status),
            ],
          ),
          const SizedBox(height: 8),
          Text('Cycle ${contribution.cycleNumber}'),
          if (paidAt != null)
            Text(formatJohannesburgDate(paidAt, includeTime: true)),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: dark ? Colors.white : const Color(0xFF020618)),
          child: child,
        ),
      ),
    );
  }
}

String _actionLabel(StokvelAction action) => switch (action) {
  StokvelAction.pay => 'Pay',
  StokvelAction.uploadProof => 'Upload proof',
  StokvelAction.confirmContributions => 'Confirm contributions',
  StokvelAction.closeCycle => 'Close cycle',
  StokvelAction.recordPayout => 'Record payout',
};