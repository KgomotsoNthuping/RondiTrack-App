import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/app/navigation/ronditrack_shell.dart';
import 'package:ronditrack/features/home/presentation/home_screen.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_detail_screen.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvels_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  final router = GoRouter(routes: $appRoutes);
  ref.onDispose(router.dispose);
  return router;
}

@TypedStatefulShellRoute<AppShellRoute>(
  branches: [
    TypedStatefulShellBranch<HomeBranch>(
      routes: [TypedGoRoute<HomeRoute>(path: '/')],
    ),
    TypedStatefulShellBranch<StokvelsBranch>(
      routes: [
        TypedGoRoute<StokvelsRoute>(
          path: '/stokvels',
          routes: [
            TypedGoRoute<StokvelDetailRoute>(
              path: ':id',
              routes: [
                TypedGoRoute<StokvelCycleRoute>(path: 'cycles/:cycleId'),
              ],
            ),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<ActivityBranch>(
      routes: [TypedGoRoute<ActivityRoute>(path: '/activity')],
    ),
    TypedStatefulShellBranch<ProfileBranch>(
      routes: [TypedGoRoute<ProfileRoute>(path: '/profile')],
    ),
  ],
)
class AppShellRoute extends StatefulShellRouteData {
  const new();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    return RondiTrackShell(navigationShell: navigationShell);
  }
}

class HomeBranch extends StatefulShellBranchData {
  const new();
}

class StokvelsBranch extends StatefulShellBranchData {
  const new();
}

class ActivityBranch extends StatefulShellBranchData {
  const new();
}

class ProfileBranch extends StatefulShellBranchData {
  const new();
}

class HomeRoute extends GoRouteData with $HomeRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const HomeScreen();
  }
}

class StokvelsRoute extends GoRouteData with $StokvelsRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const StokvelsScreen();
  }
}

class StokvelDetailRoute extends GoRouteData with $StokvelDetailRoute {
  const new({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return StokvelDetailScreen(key: ValueKey(id), stokvelId: id);
  }
}

class StokvelCycleRoute extends GoRouteData with $StokvelCycleRoute {
  const new({required this.id, required this.cycleId});

  final String id;
  final String cycleId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return StokvelCycleScreen(
      key: ValueKey((id, cycleId)),
      stokvelId: id,
      cycleId: cycleId,
    );
  }
}

class ActivityRoute extends GoRouteData with $ActivityRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const _TabRoot('Activity');
  }
}

class ProfileRoute extends GoRouteData with $ProfileRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const _TabRoot('Profile');
  }
}

class _TabRoot extends StatelessWidget {
  const new(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(title)));
  }
}