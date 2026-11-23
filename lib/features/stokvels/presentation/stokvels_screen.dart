import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/experimental/scope.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/layout/window_size.dart';
import 'package:ronditrack/core/offline/offline_enabled.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/core/widgets/failure_notice.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/offline/presentation/offline_home_screen.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_workflow_navigation.dart';

class StokvelsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(offlineEnabledProvider)) {
      final workflowScreen = stokvelWorkflowScreenFor(context);

      if (workflowScreen != null) {
        return workflowScreen;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Stokvels')),
      body: const StokvelLayout(),
    );
  }
}

@Dependencies([Home])
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

@Dependencies([Home])
class StokvelListPane extends ConsumerWidget {
  const new({this.selectedStokvelId, super.key});

  final String? selectedStokvelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(offlineEnabledProvider)) {
      return OfflineStokvelListPane(selectedStokvelId: selectedStokvelId);
    }

    final persona = ref.watch(demoSessionProvider);

    if (persona == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final provider = homeProvider(persona.name);
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
      final ScreenFailure<List<HomeEntry>> failure => <Widget>[
        FailureNotice(state: failure, onRetry: () => ref.invalidate(provider)),
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
            key: ValueKey(persona.name),
            primary: false,
            padding: const EdgeInsets.all(20),
            children: children,
          ),
        ),
      ),
    );
  }
}
