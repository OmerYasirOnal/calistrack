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

  Future<void> pumpAboutYou(WidgetTester tester) async {
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
  }

  testWidgets('About You → Continue advances toward the program step',
      (tester) async {
    await pumpAboutYou(tester);
    expect(find.text('About you'), findsOneWidget);

    await tester.tap(find.text('Intermediate'));
    await tester.tap(find.text('Skill'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The program step is reached (generation kicks off / previews).
    expect(find.text('About you'), findsNothing);
    expect(
      find.textContaining('program', findRichText: false),
      findsWidgets,
    );
  });

  testWidgets('selections survive stepping Back to Welcome and forward again',
      (tester) async {
    await pumpAboutYou(tester);

    await tester.tap(find.text('Skill'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to CalisTrack'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // The 'Skill' chip is still selected — the AutoDispose answers provider was
    // kept alive across the Back navigation rather than reset.
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Skill'),
    );
    expect(chip.selected, isTrue);
  });
}
