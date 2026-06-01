import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/exercises/data/exercise_repository.dart';
import 'package:calistrack/features/progress/presentation/progress_screen.dart';
import 'package:calistrack/features/workout/data/workout_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:calistrack/models/exercise.dart';
import 'package:calistrack/models/workout.dart';
import 'package:fl_chart/fl_chart.dart';
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

Workout _w(String date, int reps) => Workout(
      id: date,
      date: DateTime.parse(date),
      programId: 'p',
      dayLabel: 'Push',
      completed: true,
      exercises: [
        LoggedExercise(
          exerciseId: 'push_up',
          name: 'Push-up',
          sets: [LoggedSet(reps: reps, addedWeightKg: 10)],
        ),
      ],
    );

Widget _app(WorkoutRepository workouts) => ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
          ),
        ),
        workoutRepositoryProvider.overrideWithValue(workouts),
        exerciseLibraryProvider.overrideWith((ref) => _library),
      ],
      child: const MaterialApp(home: ProgressScreen()),
    );

void main() {
  testWidgets('empty history shows the empty state', (tester) async {
    await tester.pumpWidget(_app(FakeWorkoutRepository()));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Log a few workouts'),
      findsOneWidget,
    );
  });

  testWidgets('renders stats + chart for an exercise with history',
      (tester) async {
    final workouts = FakeWorkoutRepository()
      ..saved.addAll([_w('2026-06-02', 12), _w('2026-05-30', 10)]);
    await tester.pumpWidget(_app(workouts));
    await tester.pumpAndSettle();

    // Stats card.
    expect(find.text('workouts'), findsOneWidget);
    // Exercise picker resolves the name + the metric label + the chart.
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });
}
