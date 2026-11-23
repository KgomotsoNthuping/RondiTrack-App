import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/experimental/scope.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/offline/offline_enabled.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/core/widgets/failure_notice.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/presentation/home_stokvel_card.dart';
import 'package:ronditrack/features/offline/presentation/offline_home_screen.dart';
import 'package:ronditrack/features/payouts/application/payout_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';

@Dependencies([homeRepository, Home, payoutOrder, stokvelDetail])
class HomeScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(offlineEnabledProvider)) {
      return const OfflineHomeScreen();
    }

    final persona = ref.watch(demoSessionProvider);

    if (persona == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final provider = homeProvider(persona.name);
    final snapshot = ref.watch(provider);

    Future<void> refresh() async {
      try {
        await ref.refresh(provider.future);
      } on Object {}
    }

    final content = switch (homeViewState(snapshot)) {
      ScreenLoading<List<HomeEntry>>() => const <Widget>[
        Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading stokvels'),
        ),
      ],
      ScreenEmpty<List<HomeEntry>>() => const <Widget>[
        Text('You have no stokvels yet.'),
        SizedBox(height: 8),
        Text('Ask a stokvel administrator to send you an invite.'),
      ],
      final ScreenFailure<List<HomeEntry>> failure => <Widget>[
        FailureNotice(state: failure, onRetry: () => ref.invalidate(provider)),
      ],
      ScreenData<List<HomeEntry>>(:final value) => <Widget>[
        for (final entry in value)
          HomeStokvelCard(
            entry: entry,
            onTap: () {
              StokvelDetailRoute(id: entry.membership.stokvelId).go(context);
            },
          ),
      ],
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('RondiTrack'),
        actions: [
          IconButton(
            tooltip: 'Refresh stokvels',
            onPressed: snapshot.isLoading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              key: ValueKey(persona),
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'My Stokvels',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text('Signed in as ${persona.displayName}'),
                  const SizedBox(height: 20),
                  ...content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
