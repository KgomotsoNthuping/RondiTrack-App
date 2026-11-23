import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/presentation/home_stokvel_card.dart';
import 'package:ronditrack/features/offline/application/offline_account_provider.dart';
import 'package:ronditrack/features/offline/presentation/cache_view.dart';
import 'package:ronditrack/features/payments/application/payment_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_workflow_navigation.dart';

class OfflineHomeScreen extends ConsumerWidget {
  const OfflineHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionStateProvider);

    if (state is! AuthSignedIn) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final account = (
      userId: state.identity.userId,
      sessionId: state.sessionId,
    );

    ref.watch(paymentWorkerProvider(account));

    final controller = ref.watch(cachedHomeProvider(account));

    return Scaffold(
      appBar: AppBar(title: const Text('RondiTrack')),
      body: SafeArea(
        top: false,
        child: CacheView<List<HomeEntry>>(
          controller: controller,
          builder: (context, entries) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'My Stokvels',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text('Account: ${state.identity.email}'),
                    const SizedBox(height: 16),
                    const CreateStokvelAction(),
                    const SizedBox(height: 20),
                    if (entries.isEmpty) ...[
                      const Text('You have no stokvels yet.'),
                      const SizedBox(height: 8),
                      const Text(
                        'Ask a stokvel administrator to send you an invite.',
                      ),
                    ],
                    for (final entry in entries)
                      HomeStokvelCard(
                        entry: entry,
                        onTap: () {
                          StokvelDetailRoute(
                            id: entry.membership.stokvelId,
                          ).go(context);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class OfflineStokvelListPane extends ConsumerWidget {
  const OfflineStokvelListPane({
    this.selectedStokvelId,
    super.key,
  });

  final String? selectedStokvelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionStateProvider);

    if (state is! AuthSignedIn) {
      return const Center(child: CircularProgressIndicator());
    }

    final controller = ref.watch(cachedHomeProvider((
      userId: state.identity.userId,
      sessionId: state.sessionId,
    )));

    return CacheView<List<HomeEntry>>(
      controller: controller,
      builder: (context, entries) {
        final colors = Theme.of(context).colorScheme;

        return ListView(
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const CreateStokvelAction(),
            if (entries.isEmpty)
              const Text('You have no stokvels yet.'),
            for (final entry in entries)
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: Text(entry.name),
                  subtitle: Text(entry.membership.role.label),
                  trailing: const Icon(Icons.chevron_right),
                  selected:
                      entry.membership.stokvelId == selectedStokvelId,
                  selectedColor: colors.onPrimaryContainer,
                  selectedTileColor: colors.primaryContainer,
                  onTap: () {
                    StokvelDetailRoute(
                      id: entry.membership.stokvelId,
                    ).go(context);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}