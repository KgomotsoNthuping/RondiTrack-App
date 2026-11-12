import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_actions.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_status_badge.dart';

class StokvelDetailScreen extends ConsumerWidget {
  const new({required this.stokvelId, super.key});

  final String stokvelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
        final persona = ref.watch(demoSessionProvider);
    if (persona == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userId = persona.name;
    final entries = ref.watch(homeProvider(userId)).value ?? const <HomeEntry>[];
    final names = {
      for (final entry in entries) entry.membership.stokvelId: entry.name,
    };

    final provider = stokvelDetailProvider(stokvelId);
    final view = stokvelDetailViewState(ref.watch(provider));
    final name = view is ScreenData<StokvelDetail>
        ? view.value.stokvel.name
        : names[stokvelId] ?? 'Stokvel details';

    final children = switch (view) {
      ScreenLoading<StokvelDetail>() => _loading('Loading $name'),
      ScreenEmpty<StokvelDetail>() => const <Widget>[
        Text('No cycle or contributions yet.'),
        SizedBox(height: 8),
        Text('Check again after your treasurer opens a cycle.'),
      ],
      ScreenFailure<StokvelDetail>(:final message) => _failure(
        message,
        () => ref.invalidate(provider),
      ),
      ScreenData<StokvelDetail>(:final value) => _detailContent(context, value),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          if (names.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Switch stokvel',
              initialValue: stokvelId,
              icon: const Icon(Icons.swap_horiz),
              onSelected: (id) {
                StokvelDetailRoute(id: id).go(context);
              },
              itemBuilder: (_) => [
                for (final entry in names.entries)
                  PopupMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
              ],
            ),
        ],
      ),
      body: _DetailBody(children: children),
    );
  }
}

class StokvelCycleScreen extends ConsumerWidget {
  const new({required this.stokvelId, required this.cycleId, super.key});

  final String stokvelId;
  final String cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = stokvelDetailProvider(stokvelId);

    void retry() => ref.invalidate(provider);

    final children = ref.watch(provider).when<List<Widget>>(
      skipLoadingOnRefresh: false,
      loading: () => _loading('Loading cycle'),
      error: (_, _) => _failure('Could not load this cycle.', retry),
      data: (detail) {
        final cycle = detail?.stokvel.currentCycle;
        if (detail == null || cycle == null || cycle.id != cycleId) {
          return _failure('Not found', retry);
        }

        final contributions = detail.stokvel.contributions.where(
          (contribution) => contribution.cycleId == cycle.id,
        );

        return [
          _DetailCard(child: _CycleSummary(cycle: cycle)),
          ..._contributions(context, contributions),
        ];
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Cycle details')),
      body: _DetailBody(children: children),
    );
  }
}

List<Widget> _loading(String label) => [
  const Center(child: CircularProgressIndicator()),
  const SizedBox(height: 12),
  Text(label, textAlign: TextAlign.center),
];

List<Widget> _failure(String message, VoidCallback retry) => [
  Text(message),
  const SizedBox(height: 12),
  Align(
    alignment: Alignment.centerLeft,
    child: FilledButton(onPressed: retry, child: const Text('Retry')),
  ),
];

List<Widget> _detailContent(BuildContext context, StokvelDetail detail) {
  final stokvel = detail.stokvel;
  final cycle = stokvel.currentCycle;
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
            _CycleSummary(cycle: cycle),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                StokvelCycleRoute(
                  id: stokvel.membership.stokvelId,
                  cycleId: cycle.id,
                ).go(context);
              },
              child: const Text('View cycle'),
            ),
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
    ..._contributions(context, stokvel.contributions),
  ];
}

List<Widget> _contributions(
  BuildContext context,
  Iterable<Contribution> contributions,
) => [
  Text('Contributions', style: Theme.of(context).textTheme.titleLarge),
  const SizedBox(height: 8),
  if (contributions.isEmpty) const Text('No contributions yet.'),
  for (final contribution in contributions)
    _ContributionCard(contribution: contribution),
];

class _CycleSummary extends StatelessWidget {
  const new({required this.cycle});

  final ContributionCycle cycle;

  @override
  Widget build(BuildContext context) {
    final due = cycle.dueDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }
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

class _DetailBody extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: children,
          ),
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