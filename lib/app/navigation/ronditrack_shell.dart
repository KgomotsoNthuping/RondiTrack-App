import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ronditrack/core/layout/window_size.dart';

const _destinations = [
  (label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home),
  (label: 'Stokvels', icon: Icons.groups_outlined, selectedIcon: Icons.groups),
  (label: 'Activity', icon: Icons.history_outlined, selectedIcon: Icons.history),
  (label: 'Profile', icon: Icons.person_outline, selectedIcon: Icons.person),
];

class RondiTrackShell extends StatelessWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final compact = WindowSize.of(context) == WindowSize.compact;

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
          Expanded(
            key: const ValueKey('tab-content'),
            child: navigationShell,
          ),
        ],
      ),
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