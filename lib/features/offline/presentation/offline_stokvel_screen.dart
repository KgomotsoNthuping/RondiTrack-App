import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/core/theme/ronditrack_tokens.dart';
import 'package:ronditrack/core/widgets/failure_notice.dart';
import 'package:ronditrack/features/offline/application/offline_account_provider.dart';
import 'package:ronditrack/features/offline/presentation/cache_view.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_actions.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_status_badge.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvels_screen.dart';

class OfflineStokvelScreen extends ConsumerWidget {
  const OfflineStokvelScreen({
    required this.stokvelId,
    this.cycleId,
    super.key,
  });

  final String stokvelId;
  final String? cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionStateProvider);

    if (state is! AuthSignedIn) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final controller = ref.watch(
      cachedStokvelProvider((
        account: (
          userId: state.identity.userId,
          sessionId: state.sessionId,
        ),
        stokvelId: stokvelId,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          cycleId == null ? 'Stokvel details' : 'Cycle details',
        ),
      ),
      body: StokvelLayout(
        selectedStokvelId: stokvelId,
        detail: ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            final cached = controller.cached;
            final selectedCycle = cycleId;

            if (selectedCycle != null &&
                cached != null &&
                cached.value.currentCycle?.id != selectedCycle) {
              return _HistoricalCycle(
                stokvelId: stokvelId,
                cycleId: selectedCycle,
                userId: state.identity.userId,
              );
            }

            return CacheView<Stokvel>(
              controller: controller,
              builder: (context, stokvel) {
                return _StokvelBody(
                  stokvel: stokvel,
                  userId: state.identity.userId,
                  cycleOnly: cycleId != null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HistoricalCycle extends ConsumerWidget {
  const _HistoricalCycle({
    required this.stokvelId,
    required this.cycleId,
    required this.userId,
  });

  final String stokvelId;
  final String cycleId;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = stokvelDetailProvider(
      stokvelId,
      cycleId: cycleId,
    );

    return ref.watch(provider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: FailureNotice(
          state: screenFailure<Object?>(
            error,
            fallback: 'Could not load this cycle.',
          ),
          onRetry: () => ref.invalidate(provider),
        ),
      ),
      data: (detail) {
        if (detail == null ||
            detail.stokvel.currentCycle?.id != cycleId) {
          return const Center(child: Text('Not found'));
        }

        return _StokvelBody(
          stokvel: detail.stokvel,
          userId: userId,
          cycleOnly: true,
        );
      },
    );
  }
}

class _StokvelBody extends StatelessWidget {
  const _StokvelBody({
    required this.stokvel,
    required this.userId,
    required this.cycleOnly,
  });

  final Stokvel stokvel;
  final String userId;
  final bool cycleOnly;

  @override
  Widget build(BuildContext context) {
    final cycle = stokvel.currentCycle;
    final rules = stokvel.rules;

    ContributionStatus? ownStatus;

    for (final contribution in stokvel.contributions) {
      if (contribution.userId == userId &&
          contribution.cycleId == cycle?.id) {
        ownStatus = contribution.status;
        break;
      }
    }

    final actions = availableActions((
      stokvel.membership.role,
      cycle?.status,
      ownStatus,
    ));

    final contributions = cycleOnly
        ? stokvel.contributions.where(
            (item) => item.cycleId == cycle?.id,
          )
        : stokvel.contributions;

    final colors = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              stokvel.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _DetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!cycleOnly) ...[
                    Text(stokvel.membership.role.label),
                    Text(
                      '${stokvel.monthlyContribution.formatRand()} per month',
                    ),
                    Text(
                      'Members ${stokvel.memberCount} · '
                      'Period ${stokvel.currentPeriod} '
                      'of ${stokvel.totalPeriods}',
                    ),
                    const Divider(height: 24),
                  ],
                  if (cycle == null)
                    const Text('No current cycle')
                  else ...[
                    _CycleSummary(cycle: cycle),
                    const SizedBox(height: 12),
                    if (!cycleOnly)
                      FilledButton(
                        onPressed: () {
                          StokvelCycleRoute(
                            id: stokvel.membership.stokvelId,
                            cycleId: cycle.id,
                          ).go(context);
                        },
                        child: const Text('View cycle'),
                      )
                    else
                      OutlinedButton(
                        onPressed: () {
                          StokvelPayoutsRoute(
                            id: stokvel.membership.stokvelId,
                            cycleId: cycle.id,
                          ).go(context);
                        },
                        child: const Text('View payouts'),
                      ),
                  ],
                  if (!cycleOnly && actions.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text('Available actions'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final action in actions)
                          Chip(
                            label: Text(_actionLabel(action)),
                            labelStyle: TextStyle(
                              color: colors.onPrimary,
                            ),
                            backgroundColor: colors.primary,
                            side: BorderSide.none,
                          ),
                      ],
                    ),
                  ],
                  if (!cycleOnly && rules != null && rules.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text('Rules'),
                    Text(rules),
                  ],
                ],
              ),
            ),
            Text(
              'Contributions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (contributions.isEmpty)
              const Text('No contributions yet.'),
            for (final contribution in contributions)
              _DetailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contribution.memberName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(contribution.amount.formatRand()),
                        ContributionStatusBadge(
                          status: contribution.status,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Cycle ${contribution.cycleNumber}'),
                    if (contribution.paidAtUtc != null)
                      Text(
                        formatJohannesburgDate(
                          contribution.paidAtUtc!,
                          includeTime: true,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CycleSummary extends StatelessWidget {
  const _CycleSummary({required this.cycle});

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
        Text(
          due == null
              ? 'No due date set'
              : 'Due ${formatCalendarDate(due)}',
        ),
        Text('Target ${cycle.targetAmount.formatRand()}'),
        Text('Collected ${cycle.totalCollected.formatRand()}'),
        Text('Outstanding ${cycle.amountOutstanding.formatRand()}'),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ink = RondiTrackTokens.of(
      context,
    )[RondiTrackToken.cardText].foreground;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: ink),
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