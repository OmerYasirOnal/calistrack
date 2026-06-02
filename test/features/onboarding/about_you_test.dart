import 'package:calistrack/app.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/onboarding/application/onboarding_answers.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/models/app_user.dart';
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
    expect(saved.goals, containsAll(<String>['Skill', 'Strength']));
  });
}
