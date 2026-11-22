import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_flavor_scope.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/layout/window_size.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';

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
  const RondiTrackShell({required this.navigationShell, super.key});

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
  const _DemoPersonaMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(demoSessionProvider);

    if (persona == null) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<DemoPersona>(
      tooltip: 'Switch demo profile',
      initialValue: persona is DemoPersona ? persona : null,
      onSelected: (selected) {
        if (ref.read(useApiRepositoriesProvider)) {
          final router = GoRouter.of(context);

          unawaited(ref.read(sessionCoordinatorProvider).signOut());

          router.go(SignInRoute(email: selected.email).location);
        } else {
          ref.read(demoSessionProvider.notifier).select(selected);
        }
      },
      itemBuilder: (_) => [
        for (final profile in DemoPersona.values)
          CheckedPopupMenuItem(
            value: profile,
            checked: profile.email == persona.email,
            child: Text(profile.displayName),
          ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Text('Switch demo profile'),
      ),
    );
  }
}
