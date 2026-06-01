import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_shell.dart';
import '../../features/today/presentation/today_screen.dart';
import '../../features/programs/presentation/programs_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/skills/presentation/skills_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

/// Top-level route paths. Kept as constants to avoid stringly-typed nav.
abstract final class Routes {
  static const today = '/today';
  static const programs = '/programs';
  static const progress = '/progress';
  static const skills = '/skills';
  static const profile = '/profile';
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// The app router. A [StatefulShellRoute] hosts the five-tab bottom nav so each
/// tab keeps its own navigation stack and state.
final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: Routes.today,
  routes: [
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
