import '../../../models/program.dart';

/// Human-readable target for a program exercise, e.g. `3 × 12`, `3 × 45s`,
/// `5 km`, or `6 × 60s`. Picks the form that matches how the movement is
/// measured (reps / hold / distance / duration).
///
/// Assumes each movement carries exactly one target kind — the preset-integrity
/// test enforces that (a movement's only target field matches its
/// [ExerciseType]), so the precedence below is unambiguous in practice.
String targetSummary(ProgramExercise e) {
  final sets = e.targetSets;
  if (e.targetReps != null) return '$sets × ${e.targetReps}';
  if (e.targetHoldSeconds != null) return '$sets × ${e.targetHoldSeconds}s';
  if (e.targetDistanceMeters != null) {
    final m = e.targetDistanceMeters!;
    if (m >= 1000) {
      final km = m / 1000;
      return '${km.toStringAsFixed(m % 1000 == 0 ? 0 : 1)} km';
    }
    return '$m m';
  }
  if (e.targetDurationSeconds != null) {
    return '$sets × ${e.targetDurationSeconds}s';
  }
  return '$sets sets';
}
