import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_flavor_scope.dart';
import 'package:ronditrack/core/layout/window_size.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/core/widgets/failure_notice.dart';
import 'package:ronditrack/features/auth/application/dev_sign_in_provider.dart';

const List<({IconData icon, String label, IconData selectedIcon})>
_destinations = [
  (label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home),
  (label: 'Stokvels', icon: Icons.groups_outlined, selectedIcon: Icons.groups),
  (
    label: 'Activity',
    icon: Icons.history_outlined,
    selectedIcon: Icons.history,
  ),
  (label: 'Profile', icon: Icons.person_outline, selectedIcon: Icons.person),
];

class RondiTrackShell extends StatelessWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final compact = WindowSize.of(context) == WindowSize.compact;
    final showSwitcher = switch (AppFlavorScope.of(context)) {
      AppFlavor.dev => true,
      AppFlavor.staging || AppFlavor.prod => false,
    };

    void selectDestination(int index) {
      if (index != navigationShell.currentIndex) {
        navigationShell.goBranch(index);
      }
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: selectDestination,
                labelType: NavigationRailLabelType.all,
                scrollable: true,
                destinations: [
                  for (final destination in _destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(destination.label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(key: const ValueKey('tab-content'), child: navigationShell),
        ],
      ),
      persistentFooterButtons: showSwitcher ? const [_DemoPersonaMenu()] : null,
      bottomNavigationBar: compact
          ? NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: selectDestination,
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            )
          : null,
    );
  }
}

class _DemoPersonaMenu extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(demoSessionProvider);

    if (persona == null) {
      return const SizedBox.shrink();
    }

    final request = ref.watch(devSignInProvider);
    final error = request.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PopupMenuButton<DemoPersona>(
          tooltip: 'Switch demo profile',
          initialValue: persona,
          enabled: !request.isLoading,
          onSelected: (selected) {
            unawaited(
              ref.read(devSignInProvider.notifier).signIn(selected.email),
            );
          },
          itemBuilder: (_) => [
            for (final profile in DemoPersona.values)
              CheckedPopupMenuItem(
                value: profile,
                checked: profile == persona,
                child: Text(profile.displayName),
              ),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Text('Switch demo profile'),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: FailureNotice(
              state: screenFailure<Object?>(
                error,
                fallback: 'Could not switch profile.',
              ),
            ),
          ),
      ],
    );
  }
}
