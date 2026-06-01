import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/workout/application/workout_session.dart';
import 'package:calistrack/features/workout/data/workout_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:calistrack/models/program.dart';
import 'package:calistrack/models/workout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _program = Program(
  id: 'p1',
  name: 'Test',
  source: ProgramSource.preset,
  days: [
    ProgramDay(
      label: 'Push',
      exercises: [
        ProgramExercise(
          exerciseId: 'push_up',
          name: 'Push-up',
          targetSets: 3,
          targetReps: 12,
        ),
      ],
    ),
  ],
);

Future<ProviderContainer> _signedInContainer(
  FakeWorkoutRepository workouts,
) async {
  final auth = FakeAuthRepository(
    initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
  );
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      workoutRepositoryProvider.overrideWithValue(workouts),
    ],
  );
  addTearDown(() {
    auth.dispose();
    container.dispose();
  });
  // Ensure the auth state has resolved so finish() can read the uid.
  await container.read(authStateProvider.future);
  return container;
}

void main() {
  test('logs sets, computes completion + volume, and edits', () async {
    final workouts = FakeWorkoutRepository();
    final container = await _signedInContainer(workouts);
    final controller = container.read(workoutSessionProvider.notifier);

    controller.startDay(_program, _program.days.first);
    expect(container.read(workoutSessionProvider)!.targetSetTotal, 3);
    expect(container.read(workoutSessionProvider)!.completion, 0);

    controller.logSet('push_up', const LoggedSet(reps: 12, addedWeightKg: 20));
    controller.logSet('push_up', const LoggedSet(reps: 10, addedWeightKg: 20));

    var session = container.read(workoutSessionProvider)!;
    expect(session.loggedSetTotal, 2);
    expect(session.completion, closeTo(2 / 3, 1e-9));
    expect(session.volume, (12 * 20) + (10 * 20));

    controller.removeSet('push_up', 0);
    session = container.read(workoutSessionProvider)!;
    expect(session.loggedSetTotal, 1);
    expect(session.setsFor('push_up').single.reps, 10);
  });

  test('finish persists a completed workout and ends the session', () async {
    final workouts = FakeWorkoutRepository();
    final container = await _signedInContainer(workouts);
    final controller = container.read(workoutSessionProvider.notifier);

    controller.startDay(_program, _program.days.first);
    controller.logSet('push_up', const LoggedSet(reps: 12));

    final workout = await controller.finish();
    expect(workout, isNotNull);
    expect(workout!.completed, isTrue);
    expect(workout.dayLabel, 'Push');
    expect(workout.programId, 'p1');
    expect(workouts.saved, hasLength(1));
    // session cleared after finishing
    expect(container.read(workoutSessionProvider), isNull);
  });

  test('finish with nothing logged saves nothing and returns null', () async {
    final workouts = FakeWorkoutRepository();
    final container = await _signedInContainer(workouts);
    final controller = container.read(workoutSessionProvider.notifier);

    controller.startDay(_program, _program.days.first);
    final workout = await controller.finish();

    expect(workout, isNull);
    expect(workouts.saved, isEmpty);
  });

  test('finish throws when signed out', () async {
    final auth = FakeAuthRepository(); // no signed-in user
    final workouts = FakeWorkoutRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        workoutRepositoryProvider.overrideWithValue(workouts),
      ],
    );
    addTearDown(() {
      auth.dispose();
      container.dispose();
    });
    await container.read(authStateProvider.future); // resolves to null

    final controller = container.read(workoutSessionProvider.notifier)
      ..startDay(_program, _program.days.first);
    controller.logSet('push_up', const LoggedSet(reps: 5));

    await expectLater(controller.finish(), throwsStateError);
    expect(workouts.saved, isEmpty);
  });

  test('toWorkout omits movements with no logged sets', () {
    final session = WorkoutSession(
      program: _program,
      day: _program.days.first,
      startedAt: DateTime.utc(2026, 6, 1),
      setsByExercise: const {
        'push_up': [LoggedSet(reps: 12)],
        'never_logged': [],
      },
    );
    final workout = session.toWorkout();
    expect(workout.exercises, hasLength(1));
    expect(workout.exercises.single.exerciseId, 'push_up');
  });
}
