import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/experimental/scope.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/push/notification_providers.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/core/theme/ronditrack_tokens.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/offline/application/offline_account_provider.dart';
import 'package:ronditrack/features/offline/presentation/cache_view.dart';
import 'package:ronditrack/features/payments/application/payment_provider.dart';
import 'package:ronditrack/features/payouts/application/payout_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_workflow_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_forms.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_form_screens.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_status_badge.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_workflow_navigation.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvels_screen.dart';

@Dependencies([homeRepository, Home, payoutOrder, stokvelDetail])
class OfflineStokvelScreen extends ConsumerWidget {
  const new({required this.stokvelId, this.cycleId, super.key});

  final String stokvelId;
  final String? cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflowScreen = stokvelWorkflowScreenFor(
      context,
      stokvelId: stokvelId,
      cycleId: cycleId,
    );

    if (workflowScreen != null) {
      return workflowScreen;
    }

    final state = ref.watch(sessionStateProvider);

    if (state is! AuthSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final account = (userId: state.identity.userId, sessionId: state.sessionId);

    final revision = cycleId == null
        ? 0
        : ref.watch(
            pushRevisionsProvider.select(
              (values) =>
                  values[(
                    userId: account.userId,
                    sessionId: account.sessionId,
                    stokvelId: stokvelId,
                    cycleId: cycleId!,
                  )] ??
                  0,
            ),
          );

    ref.watch(paymentWorkerProvider(account));

    final controller = ref.watch(
      cachedStokvelProvider((account: account, stokvelId: stokvelId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(cycleId == null ? 'Stokvel details' : 'Cycle details'),
      ),
      body: StokvelLayout(
        selectedStokvelId: stokvelId,
        detail: ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            final cached = controller.cached;
            final selected = cycleId;

            if (selected != null &&
                cached != null &&
                cached.value.currentCycle?.id != selected) {
              return _HistoricalCycle(
                key: ValueKey((account, selected, revision)),
                stokvelId: stokvelId,
                cycleId: selected,
                account: account,
              );
            }

            return CacheView<Stokvel>(
              controller: controller,
              builder: (context, stokvel) => _StockBody(
                stokvel: stokvel,
                userId: account.userId,
                cycleOnly: selected != null,
              ),
            );
          },
        ),
      ),
    );
  }
}

@Dependencies([payoutOrder, stokvelDetail, Home, homeRepository])
class _HistoricalCycle extends ConsumerStatefulWidget {
  const new({
    required this.stokvelId,
    required this.cycleId,
    required this.account,
    super.key,
  });

  final String stokvelId;
  final String cycleId;
  final OfflineAccountKey account;

  @override
  ConsumerState<_HistoricalCycle> createState() => _HistoricalCycleState();
}

class _HistoricalCycleState extends ConsumerState<_HistoricalCycle> {
  Future<EditableCycle>? _cycle;

  @override
  Widget build(BuildContext context) {
    final workflow = ref.watch(stokvelWorkflowProvider(widget.account));

    _cycle ??= workflow.latestCycle(widget.stokvelId, widget.cycleId);

    return FutureBuilder<EditableCycle>(
      future: _cycle,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formFailure(snapshot.error!)),
                TextButton(
                  onPressed: () => setState(() {
                    _cycle = workflow.latestCycle(
                      widget.stokvelId,
                      widget.cycleId,
                    );
                  }),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }

        final cycle = snapshot.data;

        if (cycle == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Cycle ${cycle.number}'),
            CycleStatusBadge(status: cycle.status),
            Text('Target ${cycle.target.formatRand()}'),
            Text('Collected ${cycle.collected.formatRand()}'),
            if (cycle.dueDate != null)
              Text('Due ${formatCalendarDate(cycle.dueDate!)}'),
            OutlinedButton(
              onPressed: () {
                StokvelPayoutsRoute(
                  id: widget.stokvelId,
                  cycleId: widget.cycleId,
                ).go(context);
              },
              child: const Text('View payouts'),
            ),
          ],
        );
      },
    );
  }
}

@Dependencies([payoutOrder, stokvelDetail, Home, homeRepository])
class _StockBody extends StatelessWidget {
  const new({
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
    final due = cycle?.dueDate;

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
                      '${stokvel.monthlyContribution.formatRand()} '
                      'per month',
                    ),
                    Text(
                      'Members ${stokvel.memberCount} · '
                      'Period ${stokvel.currentPeriod} of '
                      '${stokvel.totalPeriods}',
                    ),
                    const Divider(height: 24),
                  ],
                  if (cycle == null)
                    const Text('No current cycle')
                  else ...[
                    Text('Cycle ${cycle.number}'),
                    CycleStatusBadge(status: cycle.status),
                    Text(
                      due == null
                          ? 'No due date set'
                          : 'Due ${formatCalendarDate(due)}',
                    ),
                    Text('Target ${cycle.targetAmount.formatRand()}'),
                    Text('Collected ${cycle.totalCollected.formatRand()}'),
                    Text(
                      'Outstanding '
                      '${cycle.amountOutstanding.formatRand()}',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        if (cycleOnly) {
                          StokvelPayoutsRoute(
                            id: stokvel.membership.stokvelId,
                            cycleId: cycle.id,
                          ).go(context);
                        } else {
                          StokvelCycleRoute(
                            id: stokvel.membership.stokvelId,
                            cycleId: cycle.id,
                          ).go(context);
                        }
                      },
                      child: Text(cycleOnly ? 'View payouts' : 'View cycle'),
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
            StokvelWorkflowActions(stokvel: stokvel, userId: userId),
            const SizedBox(height: 20),
            Text(
              'Your current contribution',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (stokvel.contributions.isEmpty)
              const Text('No contribution recorded for you in this cycle.'),
            for (final item in stokvel.contributions)
              _DetailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.memberName),
                    Text(item.amount.formatRand()),
                    ContributionStatusBadge(status: item.status),
                    if (item.paidAtUtc != null)
                      Text(
                        formatJohannesburgDate(
                          item.paidAtUtc!,
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

class _DetailCard extends StatelessWidget {
  const new({required this.child});

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
