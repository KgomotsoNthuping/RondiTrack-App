import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/layout/window_size.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

class StokvelsScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stokvels')),
      body: const StokvelLayout(),
    );
  }
}

class StokvelLayout extends StatelessWidget {
  const new({this.selectedStokvelId, this.detail, super.key});

  final String? selectedStokvelId;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final expanded = WindowSize.of(context) == WindowSize.expanded;
    final list = StokvelListPane(selectedStokvelId: selectedStokvelId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (expanded) ...[
          SizedBox(width: 288, child: list),
          const VerticalDivider(width: 1),
        ],
        Expanded(
          key: const ValueKey('stokvel-content'),
          child:
              detail ??
              (expanded
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Select a stokvel'),
                      ),
                    )
                  : list),
        ),
      ],
    );
  }
}

class StokvelListPane extends ConsumerWidget {
  const new({this.selectedStokvelId, super.key});

  final String? selectedStokvelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(demoSessionProvider);
    if (persona == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final userId = persona.name;
    final provider = homeProvider(userId);
    final view = homeViewState(ref.watch(provider));
    final colors = Theme.of(context).colorScheme;

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
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              title: Text(entry.name),
              subtitle: Text(entry.membership.role.label),
              trailing: const Icon(Icons.chevron_right),
              selected: entry.membership.stokvelId == selectedStokvelId,
              selectedColor: colors.onPrimaryContainer,
              selectedTileColor: colors.primaryContainer,
              onTap: () {
                StokvelDetailRoute(id: entry.membership.stokvelId).go(context);
              },
            ),
          ),
      ],
    };

    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: ValueKey(userId),
            primary: false,
            padding: const EdgeInsets.all(20),
            children: children,
          ),
        ),
      ),
    );
  }
}