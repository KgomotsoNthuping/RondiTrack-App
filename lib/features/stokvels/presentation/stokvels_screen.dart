import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

class StokvelsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(demoSessionProvider);
    if (persona == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final userId = persona.name;
    final provider = homeProvider(userId);
    final view = homeViewState(ref.watch(provider));

    final children = switch (view) {
      ScreenLoading<List<HomeEntry>>() => const <Widget>[
        Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading stokvels'),
        ),
      ],
      ScreenEmpty<List<HomeEntry>>() => const <Widget>[
        Text('You have no stokvels yet.'),
      ],
      ScreenFailure<List<HomeEntry>>(:final message) => <Widget>[
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
      ScreenData<List<HomeEntry>>(:final value) => <Widget>[
        for (final entry in value)
          Card(
            child: ListTile(
              title: Text(entry.name),
              subtitle: Text(entry.membership.role.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                StokvelDetailRoute(id: entry.membership.stokvelId).go(context);
              },
            ),
          ),
      ],
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Stokvels')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: ValueKey(userId),
              padding: const EdgeInsets.all(20),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}