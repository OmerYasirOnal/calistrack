import 'package:calistrack/app.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/exercises/data/exercise_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/features/programs/application/ai_program_service.dart';
import 'package:calistrack/features/programs/data/program_repository.dart';
import 'package:calistrack/features/programs/data/user_program_repository.dart';
import 'package:calistrack/features/workout/data/training_defaults.dart';
import 'package:calistrack/features/workout/data/workout_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:calistrack/models/exercise.dart';
import 'package:calistrack/models/program.dart';
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
  testWidgets(
      'full onboarding: Welcome → About You → program → primer → Today session',
      (tester) async {
    const uid = 'newbie';
    final auth = FakeAuthRepository(
      initialUser: const AppUser(uid: uid, email: 'new@b.com'),
    );
    final users = FakeUserRepository()
      ..store[uid] = const AppUser(uid: uid, email: 'new@b.com');
    final userPrograms = FakeUserProgramRepository();
    addTearDown(() {
      auth.dispose();
      users.dispose();
      userPrograms.dispose();
    });

    // Deterministic generation (a one-day Push program) so the flow is stable.
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
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          trainingDefaultsProvider.overrideWith(
            (ref) => const TrainingDefaults(
              restSecondsByType: {},
              defaultRestSeconds: 0,
            ),
          ),
        ],
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Welcome.
    expect(find.text('Welcome to CalisTrack'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // About You — capture some answers.
    await tester.tap(find.text('Intermediate'));
    await tester.tap(find.text('Skill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Program step — the recommended program is previewed.
    expect(find.text('My Plan'), findsOneWidget);
    await tester.tap(find.text('Start this program'));
    await tester.pumpAndSettle();

    // Primer.
    expect(find.text("You're all set!"), findsOneWidget);
    await tester.tap(find.text('Start training'));
    await tester.pumpAndSettle();

    // Landed on Today, mid-session (Finish button + the day's movement shown).
    expect(find.text('Welcome to CalisTrack'), findsNothing);
    expect(find.text('Finish session'), findsOneWidget);
    expect(find.text('Push-up'), findsWidgets);

    // Profile reflects answers, completion, and the active program.
    final saved = users.store[uid]!;
    expect(saved.onboardingCompletedAt, isNotNull);
    expect(saved.level, ExperienceLevel.intermediate);
    expect(saved.goals, contains('Skill'));
    expect(saved.activeProgramId, isNotNull);
    expect(userPrograms.saved, hasLength(1));
    expect(saved.activeProgramId, userPrograms.saved.single.id);
  });

  testWidgets('falls back to a local template when generation fails',
      (tester) async {
    const uid = 'newbie';
    final auth = FakeAuthRepository(
      initialUser: const AppUser(uid: uid, email: 'new@b.com'),
    );
    final users = FakeUserRepository()
      ..store[uid] = const AppUser(uid: uid, email: 'new@b.com');
    final userPrograms = FakeUserProgramRepository();
    addTearDown(() {
      auth.dispose();
      users.dispose();
      userPrograms.dispose();
    });

    // Caller throws → generate() degrades to the deterministic local fallback.
    final service = AiProgramService(
      caller: (_) async => throw Exception('function unavailable'),
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
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          trainingDefaultsProvider.overrideWith(
            (ref) => const TrainingDefaults(
              restSecondsByType: {},
              defaultRestSeconds: 0,
            ),
          ),
        ],
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The fallback program is previewed with the template note.
    expect(find.textContaining('matching template'), findsOneWidget);
    await tester.tap(find.text('Start this program'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start training'));
    await tester.pumpAndSettle();

    final saved = users.store[uid]!;
    expect(saved.onboardingCompletedAt, isNotNull);
    expect(saved.activeProgramId, isNotNull);
  });

  testWidgets('"Pick one myself" completes onboarding with no active program',
      (tester) async {
    const uid = 'newbie';
    final auth = FakeAuthRepository(
      initialUser: const AppUser(uid: uid, email: 'new@b.com'),
    );
    final users = FakeUserRepository()
      ..store[uid] = const AppUser(uid: uid, email: 'new@b.com');
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
              <Object?, Object?>{'exerciseId': 'push_up', 'targetSets': 3},
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
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          trainingDefaultsProvider.overrideWith(
            (ref) => const TrainingDefaults(
              restSecondsByType: {},
              defaultRestSeconds: 0,
            ),
          ),
        ],
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final skip = find.text('Pick one myself');
    await tester.ensureVisible(skip);
    await tester.pumpAndSettle();
    await tester.tap(skip);
    await tester.pumpAndSettle();

    // Onboarding finished, but with no program → the empty Today guides them on.
    final saved = users.store[uid]!;
    expect(saved.onboardingCompletedAt, isNotNull);
    expect(saved.activeProgramId, isNull);
    expect(userPrograms.saved, isEmpty);
    expect(find.text('No active program yet'), findsOneWidget);
  });
}
