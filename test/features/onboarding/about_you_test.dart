import 'package:calistrack/app.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/onboarding/application/onboarding_answers.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('OnboardingAnswersController', () {
    test('toggles goals/equipment and clamps days to [1,7]', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(onboardingAnswersProvider.notifier);

      c.toggleGoal('Strength');
      c.toggleGoal('Skill');
      c.toggleGoal('Strength'); // off again
      expect(container.read(onboardingAnswersProvider).goals, {'Skill'});

      c.setDays(99);
      expect(container.read(onboardingAnswersProvider).daysPerWeek, 7);
      c.setDays(0);
      expect(container.read(onboardingAnswersProvider).daysPerWeek, 1);
    });

    test('body stats can be set and cleared back to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(onboardingAnswersProvider.notifier);

      c.setHeightCm(180);
      expect(container.read(onboardingAnswersProvider).heightCm, 180);
      c.setHeightCm(null);
      expect(container.read(onboardingAnswersProvider).heightCm, isNull);
    });
  });

  testWidgets('About You answers are persisted to the profile on finish',
      (tester) async {
    const uid = 'newbie';
    final auth = FakeAuthRepository(
      initialUser: const AppUser(uid: uid, email: 'new@b.com'),
    );
    final users = FakeUserRepository()
      ..store[uid] = const AppUser(uid: uid, email: 'new@b.com');
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

    // Welcome → About You.
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Pick an experience level + a couple of goals.
    await tester.tap(find.text('Intermediate'));
    await tester.tap(find.text('Skill'));
    await tester.tap(find.text('Strength'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();

    final saved = users.store[uid]!;
    expect(saved.onboardingCompletedAt, isNotNull);
    expect(saved.level, ExperienceLevel.intermediate);
    expect(saved.goals, unorderedEquals(<String>['Skill', 'Strength']));
  });

  testWidgets('optional body stats are persisted when entered', (tester) async {
    const uid = 'newbie';
    final auth = FakeAuthRepository(
      initialUser: const AppUser(uid: uid, email: 'new@b.com'),
    );
    final users = FakeUserRepository()
      ..store[uid] = const AppUser(uid: uid, email: 'new@b.com');
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

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Expand the optional body-stats section (scroll it above the footer first
    // — the default 800x600 test surface otherwise puts it under the footer)
    // and enter values. enterText targets the field directly, no hit-test.
    final statsTile = find.text('Add body stats (optional)');
    await tester.ensureVisible(statsTile);
    await tester.pumpAndSettle();
    await tester.tap(statsTile);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Height (cm)'),
      '180',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Weight (kg)'),
      '74.5',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();

    final saved = users.store[uid]!;
    expect(saved.heightCm, 180);
    expect(saved.weightKg, 74.5);
  });

  testWidgets('answers survive stepping Back to Welcome and forward again',
      (tester) async {
    const uid = 'newbie';
    final auth = FakeAuthRepository(
      initialUser: const AppUser(uid: uid, email: 'new@b.com'),
    );
    final users = FakeUserRepository()
      ..store[uid] = const AppUser(uid: uid, email: 'new@b.com');
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

    // About You → pick a goal → Back to Welcome → forward again.
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to CalisTrack'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // The selection survived (not reset by the AutoDispose provider).
    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();
    expect(users.store[uid]!.goals, unorderedEquals(<String>['Skill']));
  });
}
