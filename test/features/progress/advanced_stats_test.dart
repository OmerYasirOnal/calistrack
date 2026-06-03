import 'package:calistrack/features/progress/application/advanced_stats.dart';
import 'package:calistrack/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LoggedExercise ex(String id, List<LoggedSet> sets) =>
      LoggedExercise(exerciseId: id, name: id, sets: sets);
  Workout wk(int day, List<LoggedExercise> exercises) => Workout(
        id: 'w$day',
        date: DateTime(2026, 6, day),
        exercises: exercises,
      );

  group('computeAdvancedStats', () {
    final asOf = DateTime(2026, 6, 30);

    test('empty when there is no recent history', () {
      final s = computeAdvancedStats(const [], asOf);
      expect(s.sessionsLast30, 0);
      expect(s.topVolumeExerciseId, isNull);
      expect(s.totalVolumeLast30, 0);
    });

    test('aggregates 30-day sessions, volume, and the top movement', () {
      final workouts = [
        wk(28, [
          ex('pull_up', [const LoggedSet(reps: 10, addedWeightKg: 10)]),
        ]), // volume 100
        wk(25, [
          ex('push_up', [const LoggedSet(reps: 20)]),
        ]), // volume 20 (bodyweight)
        wk(1, [
          ex('pull_up', [const LoggedSet(reps: 5, addedWeightKg: 10)]),
        ]), // volume 50
      ];
      final s = computeAdvancedStats(workouts, asOf);

      expect(s.sessionsLast30, 3);
      expect(s.totalVolumeLast30, closeTo(170, 1e-9));
      expect(s.topVolumeExerciseId, 'pull_up'); // 150 > push_up 20
      expect(s.topVolume, closeTo(150, 1e-9));
      expect(s.avgPerWeek, closeTo(3 * 7 / 30, 1e-9));
    });

    test('excludes workouts older than 30 days', () {
      final workouts = [
        wk(30, [
          ex('push_up', [const LoggedSet(reps: 10)]),
        ]),
        Workout(
          id: 'old',
          date: DateTime(2026, 4, 1),
          exercises: [
            ex('push_up', [const LoggedSet(reps: 10)]),
          ],
        ),
      ];
      final s = computeAdvancedStats(workouts, asOf);
      expect(s.sessionsLast30, 1);
    });
  });
}
