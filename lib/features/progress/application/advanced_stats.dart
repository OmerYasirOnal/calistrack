import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/workout.dart';
import '../../auth/data/auth_repository.dart';
import '../../workout/data/workout_repository.dart';

/// Pro-tier analytics computed from logged history. Pure data — no UI, no IO.
class AdvancedStats {
  const AdvancedStats({
    required this.sessionsLast30,
    required this.avgPerWeek,
    required this.totalVolumeLast30,
    required this.topVolumeExerciseId,
    required this.topVolume,
  });

  const AdvancedStats.empty()
      : sessionsLast30 = 0,
        avgPerWeek = 0,
        totalVolumeLast30 = 0,
        topVolumeExerciseId = null,
        topVolume = 0;

  /// Completed sessions in the last 30 days.
  final int sessionsLast30;

  /// Average sessions per week over the last 30 days.
  final double avgPerWeek;

  /// Total strength volume logged in the last 30 days.
  final double totalVolumeLast30;

  /// The exercise with the most volume in the window (null when no history).
  final String? topVolumeExerciseId;
  final double topVolume;
}

/// Computes [AdvancedStats] over [workouts] as of [asOf]. Pure → unit-tested.
AdvancedStats computeAdvancedStats(List<Workout> workouts, DateTime asOf) {
  final since = asOf.subtract(const Duration(days: 30));
  final recent = workouts.where((w) => w.date.isAfter(since)).toList();
  if (recent.isEmpty) return const AdvancedStats.empty();

  final totalVolume = recent.fold(0.0, (s, w) => s + w.totalVolume);
  final byExercise = <String, double>{};
  for (final w in recent) {
    for (final e in w.exercises) {
      byExercise[e.exerciseId] =
          (byExercise[e.exerciseId] ?? 0) + e.totalVolume;
    }
  }
  String? topId;
  var topVol = 0.0;
  byExercise.forEach((id, vol) {
    if (vol > topVol) {
      topVol = vol;
      topId = id;
    }
  });

  return AdvancedStats(
    sessionsLast30: recent.length,
    avgPerWeek: recent.length * 7 / 30,
    totalVolumeLast30: totalVolume,
    topVolumeExerciseId: topId,
    topVolume: topVol,
  );
}

final advancedStatsProvider = FutureProvider.autoDispose<AdvancedStats>((
  ref,
) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const AdvancedStats.empty();
  final workouts = await ref.watch(workoutRepositoryProvider).recent(uid);
  return computeAdvancedStats(workouts, DateTime.now());
});
