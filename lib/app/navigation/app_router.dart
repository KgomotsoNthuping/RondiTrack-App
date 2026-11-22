import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/app/navigation/auth_redirect.dart';
import 'package:ronditrack/app/navigation/ronditrack_shell.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/activity/presentation/activity_screen.dart';
import 'package:ronditrack/features/auth/presentation/register_screen.dart';
import 'package:ronditrack/features/auth/presentation/sign_in_screen.dart';
import 'package:ronditrack/features/auth/presentation/splash_screen.dart';
import 'package:ronditrack/features/home/presentation/home_screen.dart';
import 'package:ronditrack/features/invites/presentation/invite_preview_screen.dart';
import 'package:ronditrack/features/payouts/presentation/payouts_screen.dart';
import 'package:ronditrack/features/profile/presentation/profile_screen.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_detail_screen.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvels_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref, AppFlavor flavor) {
  final useApi = ref.watch(useApiRepositoriesProvider);
  final coordinator = useApi ? ref.watch(sessionCoordinatorProvider) : null;

  final demo = ValueNotifier<SessionMember?>(
    useApi ? null : ref.read(demoSessionProvider),
  );

  final router = GoRouter(
    routes: $appRoutes,
    refreshListenable: coordinator ?? demo,
    redirect: (_, state) {
      final (signedIn, restoring) = switch (coordinator?.state) {
        AuthSignedIn() => (true, false),
        AuthRestoring() => (false, true),
        AuthSignedOut() => (false, false),
        null => (demo.value != null, false),
      };

      return authRedirect(
        location: state.uri,
        signedIn: signedIn,
        restoring: restoring,
        appLinkScheme: 'ronditrack-${flavor.name}',
      );
    },
    errorBuilder: (_, _) => Scaffold(
      appBar: AppBar(title: const Text('RondiTrack')),
      body: const Center(child: Text('Not found')),
    ),
  );

  if (!useApi) {
    ref.listen(demoSessionProvider, (_, next) => demo.value = next);
  }

  ref.onDispose(() {
    router.dispose();
    demo.dispose();
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
                TypedGoRoute<StokvelCycleRoute>(
                  path: 'cycles/:cycleId',
                  routes: [TypedGoRoute<StokvelPayoutsRoute>(path: 'payouts')],
                ),
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
  const AppShellRoute();

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
  const HomeBranch();
}

class StokvelsBranch extends StatefulShellBranchData {
  const StokvelsBranch();
}

class ActivityBranch extends StatefulShellBranchData {
  const ActivityBranch();
}

class ProfileBranch extends StatefulShellBranchData {
  const ProfileBranch();
}

class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const HomeScreen();
  }
}

class JoinRoute extends GoRouteData with $JoinRoute {
  const JoinRoute({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return InvitePreviewScreen(key: ValueKey(code), code: code);
  }
}

class StokvelsRoute extends GoRouteData with $StokvelsRoute {
  const StokvelsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const StokvelsScreen();
  }
}

class StokvelDetailRoute extends GoRouteData with $StokvelDetailRoute {
  const StokvelDetailRoute({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return StokvelDetailScreen(key: ValueKey(id), stokvelId: id);
  }
}

class StokvelCycleRoute extends GoRouteData with $StokvelCycleRoute {
  const StokvelCycleRoute({required this.id, required this.cycleId});

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

class StokvelPayoutsRoute extends GoRouteData with $StokvelPayoutsRoute {
  const StokvelPayoutsRoute({required this.id, required this.cycleId});

  final String id;
  final String cycleId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return PayoutsScreen(
      key: ValueKey((id, cycleId)),
      stokvelId: id,
      cycleId: cycleId,
    );
  }
}

class ActivityRoute extends GoRouteData with $ActivityRoute {
  const ActivityRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ActivityScreen();
  }
}

class ProfileRoute extends GoRouteData with $ProfileRoute {
  const ProfileRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ProfileScreen();
  }
}

@TypedGoRoute<SignInRoute>(path: signInPath)
class SignInRoute extends GoRouteData with $SignInRoute {
  const SignInRoute({this.from, this.email});

  final String? from;
  final String? email;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return SignInScreen(key: ValueKey((from, email)), from: from, email: email);
  }
}

@TypedGoRoute<RegisterRoute>(path: registerPath)
class RegisterRoute extends GoRouteData with $RegisterRoute {
  const RegisterRoute({this.from});

  final String? from;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return RegisterScreen(from: from);
  }
}

@TypedGoRoute<SplashRoute>(path: splashPath)
class SplashRoute extends GoRouteData with $SplashRoute {
  const SplashRoute({this.from, this.auth, this.email});

  final String? from;
  final String? auth;
  final String? email;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const SplashScreen();
  }
}
