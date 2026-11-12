import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/app/navigation/ronditrack_shell.dart';
import 'package:ronditrack/features/home/presentation/home_screen.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_detail_screen.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvels_screen.dart';
import 'package:ronditrack/app/navigation/auth_redirect.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/features/activity/presentation/activity_screen.dart';
import 'package:ronditrack/features/auth/presentation/sign_in_screen.dart';
import 'package:ronditrack/features/profile/presentation/profile_screen.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/features/invites/presentation/invite_preview_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref, AppFlavor flavor) {
  final session = ValueNotifier<DemoPersona?>(ref.read(demoSessionProvider));

  final router = GoRouter(
    routes: $appRoutes,
    refreshListenable: session,
    redirect: (_, state) => authRedirect(
    location: state.uri,
    signedIn: session.value != null,
    appLinkScheme: 'ronditrack-${flavor.name}',
  ),
    errorBuilder: (_, _) => Scaffold(
      appBar: AppBar(title: const Text('RondiTrack')),
      body: const Center(child: Text('Not found')),
    ),
  );

  ref.listen(demoSessionProvider, (_, next) {
    session.value = next;
  });

  ref.onDispose(() {
    router.dispose();
    session.dispose();
  });

  return router;
}

@TypedStatefulShellRoute<AppShellRoute>(
  branches: [
    TypedStatefulShellBranch<HomeBranch>(
      routes: [
        TypedGoRoute<HomeRoute>(
          path: '/',
          routes: [TypedGoRoute<JoinRoute>(path: 'join/:code')],
        ),
      ],
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

class JoinRoute extends GoRouteData with $JoinRoute {
  const new({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return InvitePreviewScreen(key: ValueKey(code), code: code);
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
    return const ActivityScreen();
  }
}

class ProfileRoute extends GoRouteData with $ProfileRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ProfileScreen();
  }
}

@TypedGoRoute<SignInRoute>(path: signInPath)
class SignInRoute extends GoRouteData with $SignInRoute {
  const new({this.from});

  final String? from;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const SignInScreen();
  }
}