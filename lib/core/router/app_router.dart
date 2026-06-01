import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/programs/presentation/program_detail_screen.dart';
import '../../features/programs/presentation/programs_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/skills/presentation/skills_screen.dart';
import '../../features/today/presentation/today_screen.dart';
import '../../models/app_user.dart';

/// Top-level route paths. Kept as constants to avoid stringly-typed nav.
abstract final class Routes {
  static const login = '/login';
  static const register = '/register';
  static const today = '/today';
  static const programs = '/programs';
  static const progress = '/progress';
  static const skills = '/skills';
  static const profile = '/profile';
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// The app router, built as a provider so auth-state changes re-run redirects.
/// A [StatefulShellRoute] hosts the five-tab bottom nav (each tab keeps its own
/// stack); `/login` + `/register` sit outside the shell.
final goRouterProvider = Provider<GoRouter>((ref) {
  // Bridge the auth StreamProvider to a Listenable go_router can refresh on.
  final authListenable = ValueNotifier<AsyncValue<AppUser?>>(
    const AsyncValue.loading(),
  );
  ref.onDispose(authListenable.dispose);
  ref.listen<AsyncValue<AppUser?>>(
    authStateProvider,
    (_, next) => authListenable.value = next,
    fireImmediately: true,
  );

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.today,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = authListenable.value;
      // While auth is still resolving, don't bounce the user anywhere.
      if (auth.isLoading) return null;
      final signedIn = auth.valueOrNull != null;
      final loc = state.matchedLocation;
      final atAuthRoute = loc == Routes.login || loc == Routes.register;
      if (!signedIn) return atAuthRoute ? null : Routes.login;
      if (atAuthRoute) return Routes.today;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellKey,
            routes: [
              GoRoute(
                path: Routes.today,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.programs,
                builder: (context, state) => const ProgramsScreen(),
                routes: [
                  GoRoute(
                    path: ':programId',
                    builder: (context, state) => ProgramDetailScreen(
                      programId: state.pathParameters['programId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.progress,
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.skills,
                builder: (context, state) => const SkillsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
