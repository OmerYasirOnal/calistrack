import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/workout.dart';
import '../../auth/data/auth_repository.dart';
import '../../workout/data/workout_repository.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Rolling window (days) for the "this week" stat.
const _thisWeekDays = 7;

/// One workout's contribution to a single exercise's progress series.
class ExerciseDataPoint {
  const ExerciseDataPoint({
    required this.date,
    required this.totalReps,
    required this.totalVolume,
    required this.topWeight,
    required this.bestHoldSeconds,
    required this.totalDistanceMeters,
  });

  final DateTime date;
  final int totalReps;
  final double totalVolume;
  final double topWeight;
  final int bestHoldSeconds;
  final int totalDistanceMeters;
}

/// Headline training stats across all workouts.
class OverallStats {
  const OverallStats({
    required this.totalWorkouts,
    required this.totalVolume,
    required this.thisWeekWorkouts,
    required this.currentStreakDays,
  });

  const OverallStats.empty()
      : totalWorkouts = 0,
        totalVolume = 0,
        thisWeekWorkouts = 0,
        currentStreakDays = 0;

  final int totalWorkouts;
  final double totalVolume;
  final int thisWeekWorkouts;
  final int currentStreakDays;
}

/// The progress series for [exerciseId] across [workouts], oldest → newest
/// (chart-ready). Pure — unit-tested directly.
List<ExerciseDataPoint> exerciseHistory(
  List<Workout> workouts,
  String exerciseId,
) {
  final points = <ExerciseDataPoint>[];
  for (final w in workouts) {
    final logged =
        w.exercises.firstWhereOrNull((e) => e.exerciseId == exerciseId);
    if (logged == null || logged.sets.isEmpty) continue;
    points.add(
      ExerciseDataPoint(
        date: w.date,
        totalReps: logged.totalReps,
        totalVolume: logged.totalVolume,
        topWeight: logged.topWeight,
        bestHoldSeconds: logged.sets.fold(
          0,
          (m, s) => (s.holdSeconds ?? 0) > m ? s.holdSeconds! : m,
        ),
        totalDistanceMeters:
            logged.sets.fold(0, (sum, s) => sum + (s.distanceMeters ?? 0)),
      ),
    );
  }
  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}

/// Headline stats for [workouts] as of [asOf]. Streak = consecutive calendar
/// days with a workout ending today (or yesterday, so it isn't "broken" simply
/// because today's session hasn't happened yet). Pure.
OverallStats overallStats(List<Workout> workouts, DateTime asOf) {
  if (workouts.isEmpty) return const OverallStats.empty();
  final totalVolume = workouts.fold(0.0, (s, w) => s + w.totalVolume);
  final weekAgo = asOf.subtract(const Duration(days: _thisWeekDays));
  final thisWeek = workouts.where((w) => w.date.isAfter(weekAgo)).length;

  final days = workouts.map((w) => _dateOnly(w.date)).toSet();
  var cursor = _dateOnly(asOf);
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return OverallStats(
    totalWorkouts: workouts.length,
    totalVolume: totalVolume,
    thisWeekWorkouts: thisWeek,
    currentStreakDays: streak,
  );
}

/// Aggregates logged workouts into progress insight. Reads history through the
/// [WorkoutRepository]; the aggregation itself is the pure functions above.
class ProgressRepository {
  ProgressRepository(this._workouts);

  final WorkoutRepository _workouts;

  /// Caps reads at the most-recent N workouts — stats/streak/history reflect
  /// this window (ample for an MVP; revisit if a user exceeds it).
  static const _historyLimit = 200;

  Future<List<ExerciseDataPoint>> historyFor(
    String uid,
    String exerciseId,
  ) async =>
      exerciseHistory(
        await _workouts.recent(uid, limit: _historyLimit),
        exerciseId,
      );

  Future<OverallStats> overall(String uid, {DateTime? asOf}) async =>
      overallStats(
        await _workouts.recent(uid, limit: _historyLimit),
        asOf ?? DateTime.now(),
      );

  /// Exercise ids that appear in any workout, most-recently-trained first.
  Future<List<String>> exercisesWithHistory(String uid) async {
    final workouts = await _workouts.recent(uid, limit: _historyLimit);
    final seen = <String>{};
    final ordered = <String>[];
    for (final w in workouts) {
      for (final e in w.exercises) {
        if (seen.add(e.exerciseId)) ordered.add(e.exerciseId);
      }
    }
    return ordered;
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(workoutRepositoryProvider)),
);

final overallStatsProvider =
    FutureProvider.autoDispose<OverallStats>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const OverallStats.empty();
  return ref.watch(progressRepositoryProvider).overall(uid);
});

final exercisesWithHistoryProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const [];
  return ref.watch(progressRepositoryProvider).exercisesWithHistory(uid);
});

final exerciseHistoryProvider = FutureProvider.autoDispose
    .family<List<ExerciseDataPoint>, String>((ref, exerciseId) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const [];
  return ref.watch(progressRepositoryProvider).historyFor(uid, exerciseId);
});
