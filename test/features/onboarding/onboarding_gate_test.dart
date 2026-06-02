import 'package:calistrack/app.dart';
import 'package:calistrack/core/router/app_router.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/onboarding/presentation/onboarding_screen.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

AsyncValue<AppUser?> _data(AppUser? u) => AsyncValue.data(u);

void main() {
  group('authRedirect (pure gate)', () {
    const signedOut = AsyncValue<AppUser?>.data(null);
    final signedIn = _data(const AppUser(uid: 'u1', email: 'a@b.com'));
    const noProfile = AsyncValue<AppUser?>.data(null);
    final pendingOnboarding = _data(const AppUser(uid: 'u1', email: 'a@b.com'));
    final doneOnboarding = _data(
      AppUser(
        uid: 'u1',
        email: 'a@b.com',
        onboardingCompletedAt: DateTime(2026, 5, 1),
      ),
    );

    test('auth still loading → stays put (no bounce)', () {
      expect(
        authRedirect(
          auth: const AsyncValue.loading(),
          profile: const AsyncValue.loading(),
          location: Routes.today,
        ),
        isNull,
      );
    });

    test('signed out → /login (unless already on an auth route)', () {
      expect(
        authRedirect(
          auth: signedOut,
          profile: noProfile,
          location: Routes.today,
        ),
        Routes.login,
      );
      expect(
        authRedirect(
          auth: signedOut,
          profile: noProfile,
          location: Routes.login,
        ),
        isNull,
      );
      expect(
        authRedirect(
          auth: signedOut,
          profile: noProfile,
          location: Routes.register,
        ),
        isNull,
      );
    });

    test('signed in, profile not loaded yet → not forced to onboarding', () {
      // At a protected route, stay (no profile doc to gate on yet).
      expect(
        authRedirect(
          auth: signedIn,
          profile: noProfile,
          location: Routes.today,
        ),
        isNull,
      );
      // But never sit on the auth screen once signed in.
      expect(
        authRedirect(
          auth: signedIn,
          profile: noProfile,
          location: Routes.login,
        ),
        Routes.today,
      );
    });

    test('signed in, onboarding pending → /onboarding', () {
      expect(
        authRedirect(
          auth: signedIn,
          profile: pendingOnboarding,
          location: Routes.today,
        ),
        Routes.onboarding,
      );
      // Already on onboarding → stay.
      expect(
        authRedirect(
          auth: signedIn,
          profile: pendingOnboarding,
          location: Routes.onboarding,
        ),
        isNull,
      );
    });

    test('signed in, onboarding done → kept out of auth + onboarding routes',
        () {
      expect(
        authRedirect(
          auth: signedIn,
          profile: doneOnboarding,
          location: Routes.onboarding,
        ),
        Routes.today,
      );
      expect(
        authRedirect(
          auth: signedIn,
          profile: doneOnboarding,
          location: Routes.login,
        ),
        Routes.today,
      );
      // A normal protected route is fine.
      expect(
        authRedirect(
          auth: signedIn,
          profile: doneOnboarding,
          location: Routes.programs,
        ),
        isNull,
      );
    });
  });

  testWidgets('a new user is routed to onboarding, an onboarded one to Today',
      (tester) async {
    final auth = FakeAuthRepository(
      initialUser: const AppUser(uid: 'newbie', email: 'new@b.com'),
    );
    // A profile doc exists (as _bootstrapProfile would create) with the
    // onboarding flag unset.
    final users = FakeUserRepository()
      ..store['newbie'] = const AppUser(uid: 'newbie', email: 'new@b.com');
    addTearDown(() {
      auth.dispose();
      users.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
        ],
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    // New user → onboarding (Welcome), not the empty Today shell. (The full
    // completion path is covered by onboarding_flow_test.)
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Welcome to CalisTrack'), findsOneWidget);
    expect(find.text('No active program yet'), findsNothing);
  });
}
