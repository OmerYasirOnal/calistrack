import 'package:calistrack/features/progress/data/progress_repository.dart';
import 'package:calistrack/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

Workout _w(String date, List<LoggedExercise> exercises) => Workout(
      id: date,
      date: DateTime.parse(date),
      programId: 'p',
      dayLabel: 'D',
      completed: true,
      exercises: exercises,
    );

LoggedExercise _le(String id, List<LoggedSet> sets) =>
    LoggedExercise(exerciseId: id, name: id, sets: sets);

void main() {
  group('exerciseHistory', () {
    test('builds chart-ready points (oldest → newest) with aggregates', () {
      // recent() yields newest-first; aggregation must re-sort ascending.
      final workouts = [
        _w('2026-06-02', [
          _le('dip', const [LoggedSet(reps: 8, addedWeightKg: 20)]),
        ]),
        _w('2026-05-30', [
          _le('dip', const [
            LoggedSet(reps: 10, addedWeightKg: 10),
            LoggedSet(reps: 9, addedWeightKg: 10),
          ]),
          _le('plank', const [LoggedSet(reps: 1, holdSeconds: 40)]),
        ]),
      ];

      final dip = exerciseHistory(workouts, 'dip');
      expect(dip.map((p) => p.date), [
        DateTime.parse('2026-05-30'),
        DateTime.parse('2026-06-02'),
      ]);
      expect(dip.first.totalReps, 19); // 10 + 9
      expect(dip.first.totalVolume, (10 * 10) + (9 * 10));
      expect(dip.last.topWeight, 20);

      final plank = exerciseHistory(workouts, 'plank');
      expect(plank, hasLength(1));
      expect(plank.single.bestHoldSeconds, 40);

      expect(exerciseHistory(workouts, 'never'), isEmpty);
    });

    test('one point per workout for the same exercise across sessions', () {
      final workouts = [
        _w('2026-06-02', [
          _le('pull_up', const [LoggedSet(reps: 8)]),
        ]),
        _w('2026-05-28', [
          _le('pull_up', const [LoggedSet(reps: 6), LoggedSet(reps: 5)]),
        ]),
      ];
      final history = exerciseHistory(workouts, 'pull_up');
      expect(history, hasLength(2)); // one point per workout, not per set
      expect(history.first.totalReps, 11); // earliest session: 6 + 5
      expect(history.last.totalReps, 8);
    });

    test('aggregates cardio distance', () {
      final workouts = [
        _w('2026-06-01', [
          _le('easy_run', const [LoggedSet(reps: 1, distanceMeters: 5000)]),
        ]),
      ];
      final history = exerciseHistory(workouts, 'easy_run');
      expect(history.single.totalDistanceMeters, 5000);
    });
  });

  group('overallStats', () {
    final asOf = DateTime.parse('2026-06-02');

    test('empty history → zeroed stats', () {
      final stats = overallStats(const [], asOf);
      expect(stats.totalWorkouts, 0);
      expect(stats.currentStreakDays, 0);
    });

    test('totals + this-week window', () {
      final workouts = [
        _w('2026-06-02', [
          _le('dip', const [LoggedSet(reps: 5, addedWeightKg: 10)]),
        ]),
        _w('2026-05-20', [
          _le('dip', const [LoggedSet(reps: 5, addedWeightKg: 10)]),
        ]),
      ];
      final stats = overallStats(workouts, asOf);
      expect(stats.totalWorkouts, 2);
      expect(stats.totalVolume, (5 * 10) * 2);
      expect(stats.thisWeekWorkouts, 1); // only 06-02 is within 7 days
    });

    test('streak counts consecutive days ending today', () {
      final workouts = [
        _w('2026-06-02', const []),
        _w('2026-06-01', const []),
        _w('2026-05-31', const []),
        _w('2026-05-29', const []), // gap on 05-30 breaks the streak here
      ];
      expect(overallStats(workouts, asOf).currentStreakDays, 3);
    });

    test('streak survives a not-yet-trained today (counts from yesterday)', () {
      final workouts = [
        _w('2026-06-01', const []),
        _w('2026-05-31', const []),
      ];
      expect(overallStats(workouts, asOf).currentStreakDays, 2);
    });

    test('stale history → no current streak', () {
      final stats = overallStats([_w('2026-05-28', const [])], asOf);
      expect(stats.currentStreakDays, 0);
    });
  });

  group('ProgressRepository', () {
    test('historyFor + exercisesWithHistory read through the repo', () async {
      final workouts = FakeWorkoutRepository()
        ..saved.addAll([
          _w('2026-06-02', [
            _le('dip', const [LoggedSet(reps: 8, addedWeightKg: 20)]),
          ]),
          _w('2026-05-30', [
            _le('pull_up', const [LoggedSet(reps: 6)]),
          ]),
        ]);
      final repo = ProgressRepository(workouts);

      final dip = await repo.historyFor('u1', 'dip');
      expect(dip.single.topWeight, 20);

      // most-recently-trained first
      expect(await repo.exercisesWithHistory('u1'), ['dip', 'pull_up']);
    });
  });
}
