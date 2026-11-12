import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/presentation/home_stokvel_card.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(demoSessionProvider);
    final provider = homeProvider(persona.name);
    final snapshot = ref.watch(provider);

    Future<void> refresh() async {
      try {
        await ref.refresh(provider.future);
      } on Object {}
    }

    final content = switch (homeViewState(snapshot)) {
      ScreenLoading<List<HomeEntry>>() => const [
        Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading stokvels'),
        ),
      ],
      ScreenEmpty<List<HomeEntry>>() => const [
        Text('You have no stokvels yet.'),
        SizedBox(height: 8),
        Text('Ask a stokvel administrator to send you an invite.'),
      ],
      ScreenFailure<List<HomeEntry>>(:final message) => [
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
      ScreenData<List<HomeEntry>>(:final value) => [
        for (final entry in value)
          HomeStokvelCard(
            entry: entry,
            onTap: () async {
              final stokvelNames = {
                for (final item in value) item.membership.stokvelId: item.name,
              };

              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => StokvelDetailScreen(
                    initialStokvelId: entry.membership.stokvelId,
                    stokvelNames: stokvelNames,
                  ),
                ),
              );
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
          PopupMenuButton<DemoPersona>(
            tooltip: 'Switch demo profile',
            initialValue: persona,
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (profile) {
              ref.read(demoSessionProvider.notifier).select(profile);
            },
            itemBuilder: (_) => [
              for (final profile in DemoPersona.values)
                PopupMenuItem(value: profile, child: Text(profile.displayName)),
            ],
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
