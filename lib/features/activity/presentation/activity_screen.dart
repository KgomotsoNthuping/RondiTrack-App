import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/activity/application/activity_provider.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_status_badge.dart';

class ActivityScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(demoSessionProvider);
    if (persona == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final provider = activityFeedProvider(persona.name);
    final view = activityViewState(ref.watch(provider));

    final children = switch (view) {
      ScreenLoading<List<ActivityEntry>>() => const <Widget>[
        Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading activity'),
        ),
      ],
      ScreenEmpty<List<ActivityEntry>>() => const <Widget>[
        Text('No activity yet.'),
      ],
      ScreenFailure<List<ActivityEntry>>(:final message) => <Widget>[
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
      ScreenData<List<ActivityEntry>>(:final value) => <Widget>[
        for (final entry in value) _ActivityCard(entry: entry),
      ],
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: ValueKey(persona),
              padding: const EdgeInsets.all(20),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const new({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final contribution = entry.contribution;
    final paidAt = contribution.paidAtUtc;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.stokvelName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${contribution.memberName} · ${contribution.amount.formatRand()}',
            ),
            if (paidAt != null)
              Text(formatJohannesburgDate(paidAt, includeTime: true)),
            const SizedBox(height: 8),
            ContributionStatusBadge(status: contribution.status),
          ],
        ),
      ),
    );
  }
}