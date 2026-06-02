import 'package:calistrack/app.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/features/skills/data/skill_repository.dart';
import 'package:calistrack/features/skills/presentation/skill_detail_screen.dart';
import 'package:calistrack/features/skills/presentation/skills_screen.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:calistrack/models/skill_progress.dart';
import 'package:flutter/material.dart';
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
    final me = onboardedUser();
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
    // No progress yet → the intro is shown.
    expect(find.textContaining('Work toward these skills'), findsOneWidget);

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

  testWidgets('completed skill shows the trophy and step-back recovers',
      (tester) async {
    final skills = FakeSkillRepository(_presets)
      ..saved['pistol'] = (currentStepIndex: 1, logs: []); // 1 step → done
    addTearDown(skills.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
            ),
          ),
          skillRepositoryProvider.overrideWithValue(skills),
        ],
        child: const MaterialApp(home: SkillDetailScreen(skillId: 'pistol')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Skill complete'), findsOneWidget);
    expect(find.text('Mark step complete'), findsNothing);

    await tester.tap(find.text('Step back'));
    await tester.pumpAndSettle();
    expect(skills.setStepCalls, 1);
    expect(skills.saved['pistol']?.currentStepIndex, 0);
  });

  testWidgets('unknown skill id shows not found', (tester) async {
    final skills = FakeSkillRepository(_presets);
    addTearDown(skills.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
            ),
          ),
          skillRepositoryProvider.overrideWithValue(skills),
        ],
        child: const MaterialApp(home: SkillDetailScreen(skillId: 'nope')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Skill not found.'), findsOneWidget);
  });

  testWidgets('the intro is hidden once a skill has progress', (tester) async {
    final auth = FakeAuthRepository(
      initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
    );
    final skills = FakeSkillRepository(_presets)
      ..saved['front_lever'] = (currentStepIndex: 1, logs: const []);
    addTearDown(() {
      auth.dispose();
      skills.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          skillRepositoryProvider.overrideWithValue(skills),
        ],
        child: const MaterialApp(home: SkillsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Front Lever'), findsOneWidget);
    // A skill has advanced → the intro auto-hides.
    expect(find.textContaining('Work toward these skills'), findsNothing);
  });
}
