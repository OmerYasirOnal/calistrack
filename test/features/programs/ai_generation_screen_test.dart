import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/exercises/data/exercise_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/features/programs/application/ai_program_service.dart';
import 'package:calistrack/features/programs/data/program_repository.dart';
import 'package:calistrack/features/programs/data/user_program_repository.dart';
import 'package:calistrack/features/programs/presentation/ai_generation_screen.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:calistrack/models/exercise.dart';
import 'package:calistrack/models/program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _library = [
  Exercise(
    id: 'push_up',
    name: 'Push-up',
    muscleGroup: MuscleGroup.push,
    type: ExerciseType.reps,
  ),
];

const _presets = [
  Program(
    id: 'foundations',
    name: 'Foundations',
    source: ProgramSource.preset,
    days: [
      ProgramDay(
        label: 'Full Body',
        exercises: [
          ProgramExercise(
            exerciseId: 'push_up',
            name: 'Push-up',
            targetSets: 3,
            targetReps: 8,
          ),
        ],
      ),
    ],
  ),
];

void main() {
  testWidgets('generate → preview → save persists + sets active',
      (tester) async {
    const me = AppUser(uid: 'u1', email: 'a@b.com');
    final auth = FakeAuthRepository(initialUser: me);
    final users = FakeUserRepository()..store['u1'] = me;
    final userPrograms = FakeUserProgramRepository();
    addTearDown(() {
      auth.dispose();
      users.dispose();
      userPrograms.dispose();
    });

    final service = AiProgramService(
      caller: (_) async => <String, dynamic>{
        'name': 'My Plan',
        'days': <Object?>[
          <Object?, Object?>{
            'label': 'Push',
            'exercises': <Object?>[
              <Object?, Object?>{
                'exerciseId': 'push_up',
                'targetSets': 3,
                'targetReps': 10,
              },
            ],
          },
        ],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
          userProgramRepositoryProvider.overrideWithValue(userPrograms),
          exerciseLibraryProvider.overrideWith((ref) => _library),
          presetProgramsProvider.overrideWith((ref) => _presets),
          aiProgramServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: AiGenerationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Form → generate.
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    // Preview of the generated program.
    expect(find.text('My Plan'), findsOneWidget);
    expect(find.text('Push-up'), findsOneWidget);

    // Save → persisted + active.
    await tester.tap(find.text('Save & set active'));
    await tester.pumpAndSettle();
    expect(userPrograms.saved, hasLength(1));
    expect(users.store['u1']?.activeProgramId, userPrograms.saved.single.id);
  });
}
