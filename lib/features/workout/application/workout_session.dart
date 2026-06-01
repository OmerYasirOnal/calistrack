import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/program.dart';
import '../../../models/workout.dart';
import '../../auth/data/auth_repository.dart';
import '../data/workout_repository.dart';

/// An in-progress training session for one program day. Immutable — the
/// controller swaps it wholesale on each edit so the UI rebuilds cleanly.
class WorkoutSession {
  const WorkoutSession({
    required this.program,
    required this.day,
    required this.startedAt,
    this.setsByExercise = const {},
  });

  final Program program;
  final ProgramDay day;
  final DateTime startedAt;

  /// exerciseId → the sets logged so far this session.
  final Map<String, List<LoggedSet>> setsByExercise;

  List<LoggedSet> setsFor(String exerciseId) =>
      setsByExercise[exerciseId] ?? const [];

  int get targetSetTotal =>
      day.exercises.fold(0, (sum, e) => sum + e.targetSets);

  int get loggedSetTotal =>
      setsByExercise.values.fold(0, (sum, sets) => sum + sets.length);

  /// 0..1 — fraction of target sets logged.
  double get completion => targetSetTotal == 0
      ? 0
      : (loggedSetTotal / targetSetTotal).clamp(0.0, 1.0);

  double get volume => setsByExercise.values
      .expand((sets) => sets)
      .fold(0.0, (sum, set) => sum + set.volume);

  bool get hasAnySet => loggedSetTotal > 0;

  WorkoutSession copyWith({Map<String, List<LoggedSet>>? setsByExercise}) =>
      WorkoutSession(
        program: program,
        day: day,
        startedAt: startedAt,
        setsByExercise: setsByExercise ?? this.setsByExercise,
      );

  /// Snapshot the session as a persistable [Workout] (only movements that were
  /// actually logged are included).
  Workout toWorkout() => Workout(
        id: '${program.id}_${startedAt.millisecondsSinceEpoch}',
        date: startedAt,
        programId: program.id,
        dayLabel: day.label,
        completed: true,
        exercises: [
          for (final ex in day.exercises)
            if (setsFor(ex.exerciseId).isNotEmpty)
              LoggedExercise(
                exerciseId: ex.exerciseId,
                name: ex.name,
                sets: setsFor(ex.exerciseId),
              ),
        ],
      );
}

/// Owns the active [WorkoutSession] (null when none is running) and the
/// log/edit/finish actions. Kept alive so an in-progress session survives tab
/// switches; it is cleared explicitly on finish/cancel.
class WorkoutSessionController extends Notifier<WorkoutSession?> {
  @override
  WorkoutSession? build() => null;

  void startDay(Program program, ProgramDay day) {
    state = WorkoutSession(
      program: program,
      day: day,
      startedAt: DateTime.now(),
    );
  }

  void cancel() => state = null;

  void logSet(String exerciseId, LoggedSet set) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      setsByExercise: {
        ...session.setsByExercise,
        exerciseId: [...session.setsFor(exerciseId), set],
      },
    );
  }

  void removeSet(String exerciseId, int index) {
    final session = state;
    if (session == null) return;
    final sets = [...session.setsFor(exerciseId)];
    if (index < 0 || index >= sets.length) return;
    sets.removeAt(index);
    state = session.copyWith(
      setsByExercise: {...session.setsByExercise, exerciseId: sets},
    );
  }

  /// Persists the session (if anything was logged) and ends it, returning the
  /// saved [Workout] for the summary. Returns null if there was nothing to save.
  Future<Workout?> finish() async {
    final session = state;
    if (session == null || !session.hasAnySet) return null;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      throw StateError('Cannot finish a workout while signed out.');
    }
    final workout = session.toWorkout();
    await ref.read(workoutRepositoryProvider).save(uid, workout);
    state = null;
    return workout;
  }
}

final workoutSessionProvider =
    NotifierProvider<WorkoutSessionController, WorkoutSession?>(
  WorkoutSessionController.new,
);

/// The sets logged for [exerciseId] last time it was trained ("last time"
/// reference + pre-fill). Empty when never logged or signed out.
final lastSetsForProvider =
    FutureProvider.family<List<LoggedSet>, String>((ref, exerciseId) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const [];
  return ref.watch(workoutRepositoryProvider).lastSetsFor(uid, exerciseId);
});
