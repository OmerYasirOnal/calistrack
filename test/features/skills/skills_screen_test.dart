import 'package:calistrack/app.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/features/skills/data/skill_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:calistrack/models/skill_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _presets = [
  SkillProgress(
    id: 'front_lever',
    name: 'Front Lever',
    description: 'A horizontal hold.',
    steps: [
      SkillStep(id: 'tuck', name: 'Tuck', targetHoldSeconds: 15),
      SkillStep(id: 'adv', name: 'Advanced tuck', targetHoldSeconds: 15),
    ],
  ),
  SkillProgress(
    id: 'pistol',
    name: 'Pistol Squat',
    steps: [SkillStep(id: 'assisted', name: 'Assisted', targetReps: 8)],
  ),
];

void main() {
  testWidgets('lists skills, opens a detail, logs an attempt + advances',
      (tester) async {
    const me = AppUser(uid: 'u1', email: 'a@b.com');
    final auth = FakeAuthRepository(initialUser: me);
    final users = FakeUserRepository()..store['u1'] = me;
    final skills = FakeSkillRepository(_presets);
    addTearDown(() {
      auth.dispose();
      users.dispose();
      skills.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
          skillRepositoryProvider.overrideWithValue(skills),
        ],
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Skills tab lists the trees.
    await tester.tap(find.text('Skills'));
    await tester.pumpAndSettle();
    expect(find.text('Front Lever'), findsOneWidget);
    expect(find.text('Pistol Squat'), findsOneWidget);

    // Open a skill → step ladder.
    await tester.tap(find.text('Front Lever'));
    await tester.pumpAndSettle();
    expect(find.text('Tuck'), findsOneWidget);
    expect(find.text('Advanced tuck'), findsOneWidget);

    // Log an attempt.
    await tester.tap(find.text('Log attempt'));
    await tester.pumpAndSettle();
    expect(skills.logCalls, 1);
    expect(skills.saved['front_lever']?.logs, hasLength(1));

    // Advance the current step.
    await tester.tap(find.text('Mark step complete'));
    await tester.pumpAndSettle();
    expect(skills.setStepCalls, 1);
    expect(skills.saved['front_lever']?.currentStepIndex, 1);
  });
}
