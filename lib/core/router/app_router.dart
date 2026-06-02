import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/application/profile_providers.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/programs/presentation/program_detail_screen.dart';
import '../../features/programs/presentation/programs_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/skills/presentation/skill_detail_screen.dart';
import '../../features/skills/presentation/skills_screen.dart';
import '../../features/today/presentation/today_screen.dart';
import '../../models/app_user.dart';

/// Top-level route paths. Kept as constants to avoid stringly-typed nav.
abstract final class Routes {
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const programs = '/programs';
  static const progress = '/progress';
  static const skills = '/skills';
  static const profile = '/profile';

  /// Detail route for a single program, e.g. `/programs/classic_ppl`.
  static String programDetail(String programId) => '$programs/$programId';

  /// Detail route for a single skill, e.g. `/skills/muscle_up`.
  static String skillDetail(String skillId) => '$skills/$skillId';
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// Pure gating logic for the router's redirect. Extracted so its many branches
/// (signed-out, onboarding-pending, fully-onboarded, profile-still-loading) can
/// be unit-tested without spinning up a full navigator.
///
/// [auth] is the auth *identity*; [profile] is the Firestore profile document
/// that carries `onboardingCompletedAt`. Returns the path to redirect to, or
/// null to stay put.
@visibleForTesting
String? authRedirect({
  required AsyncValue<AppUser?> auth,
  required AsyncValue<AppUser?> profile,
  required String location,
}) {
  // Don't bounce the user while the auth identity is still resolving.
  if (auth.isLoading) return null;

  final identity = auth.valueOrNull;
  final signedIn = identity != null;
  final atAuthRoute = location == Routes.login || location == Routes.register;
  final atOnboarding = location == Routes.onboarding;

  if (!signedIn) return atAuthRoute ? null : Routes.login;

  // A guest (anonymous) session may reach /register to upgrade in place — the
  // gate would otherwise bounce a signed-in user off the auth routes.
  if (identity.isAnonymous && location == Routes.register) return null;

  // Signed in. The onboarding decision needs the Firestore profile. Until we
  // actually have it (still loading, errored, or the doc isn't written yet),
  // neither force onboarding nor trap the user there — just keep them off the
  // auth screens.
  final user = profile.valueOrNull;
  if (user == null) return atAuthRoute ? Routes.today : null;

  if (user.onboardingCompletedAt == null) {
    return atOnboarding ? null : Routes.onboarding;
  }

  // Fully onboarded: the auth + onboarding routes are off-limits.
  if (atAuthRoute || atOnboarding) return Routes.today;
  return null;
}

/// The app router, built as a provider so auth-state changes re-run redirects.
/// A [StatefulShellRoute] hosts the five-tab bottom nav (each tab keeps its own
/// stack); `/login` + `/register` sit outside the shell.
final goRouterProvider = Provider<GoRouter>((ref) {
  // Bridge the auth identity *and* the profile doc to a Listenable go_router
  // can refresh on — the onboarding gate keys off the profile, so the router
  // must re-run its redirect when either changes.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(
    authStateProvider,
    (_, __) => refresh.value++,
    fireImmediately: true,
  );
  ref.listen(
    currentUserProfileProvider,
    (_, __) => refresh.value++,
    fireImmediately: true,
  );

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.today,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      auth: ref.read(authStateProvider),
      profile: ref.read(currentUserProfileProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
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
                routes: [
                  GoRoute(
                    path: ':skillId',
                    builder: (context, state) => SkillDetailScreen(
                      skillId: state.pathParameters['skillId']!,
                    ),
                  ),
                ],
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
