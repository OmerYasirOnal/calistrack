import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/workout.dart';
import '../../auth/data/auth_repository.dart';
import '../../workout/data/workout_repository.dart';
import 'progression_model.dart';

/// One past session's summary for a single exercise (newest-first input).
/// `topReps` and `topWeightKg` come from the SAME set — the top working set —
/// so the model's rep evidence and the load the suggestion builds on stay
/// coherent in mixed-load sessions.
class _SessionStat {
  const _SessionStat(this.topReps, this.topWeightKg, this.avgRir);
  final int topReps;
  final double topWeightKg;
  final double? avgRir;
}

/// Default reps-in-reserve assumed when the user logged no effort — a moderate
/// effort (matches the trainer's `avg_rir` default of 2.0).
const _defaultRir = 2.0;

/// Reps below the target that defines the bottom of the implied rep range.
const _repRange = 4;

/// The smallest load step we add/remove (kg).
const _loadStep = 2.5;

_SessionStat? _statFor(Workout w, String exerciseId) {
  final logged = w.exercises.firstWhereOrNull(
    (e) => e.exerciseId == exerciseId,
  );
  if (logged == null || logged.sets.isEmpty) return null;
  // The "top working set" = heaviest, tie-broken by reps. For pure bodyweight
  // work (all addedWeight 0) this is just the highest-rep set; for weighted work
  // it's the set you'd actually progress — and its reps + weight are coherent.
  final top = logged.sets.reduce((a, b) {
    if (a.addedWeightKg != b.addedWeightKg) {
      return a.addedWeightKg > b.addedWeightKg ? a : b;
    }
    return a.reps >= b.reps ? a : b;
  });
  final rirs =
      logged.sets.map((s) => s.rir).whereType<int>().toList(growable: false);
  final avgRir =
      rirs.isEmpty ? null : rirs.reduce((a, b) => a + b) / rirs.length;
  return _SessionStat(top.reps, top.addedWeightKg, avgRir);
}

/// Builds the model's base-6 input from recent history for [exerciseId] given a
/// rep-based program target. Returns null when there's no logged history for the
/// exercise (nothing to learn from yet). [workoutsNewestFirst] is the user's
/// recent workouts, most-recent first (as `WorkoutRepository.recent` returns).
ProgressionInput? buildProgressionInput(
  List<Workout> workoutsNewestFirst,
  String exerciseId,
  int targetReps,
) {
  final stats = <_SessionStat>[];
  for (final w in workoutsNewestFirst) {
    final s = _statFor(w, exerciseId);
    if (s != null) stats.add(s);
  }
  if (stats.isEmpty) return null;

  final last = stats.first;
  final repHigh = targetReps.toDouble();

  // Consecutive most-recent sessions at/above the target.
  var sessionsAtTop = 0;
  for (final s in stats) {
    if (s.topReps >= targetReps) {
      sessionsAtTop++;
    } else {
      break;
    }
  }

  // trend3: mean per-session change in top reps over the last <=3 sessions.
  final recent = stats.take(3).toList(); // newest-first
  double trend3 = 0;
  if (recent.length >= 2) {
    // chronological: oldest -> newest
    final chron = recent.reversed.toList();
    var sum = 0.0;
    for (var i = 1; i < chron.length; i++) {
      sum += (chron[i].topReps - chron[i - 1].topReps);
    }
    trend3 = sum / (chron.length - 1);
  }

  return ProgressionInput(
    topRepsLast: last.topReps.toDouble(),
    repHigh: repHigh,
    sessionsAtTop: sessionsAtTop.toDouble(),
    trend3: trend3,
    avgRir: last.avgRir ?? _defaultRir,
    lastTopWeightKg: last.topWeightKg,
  );
}

double _roundHalf(double v) => (v * 2).round() / 2;

/// Turns the model's action into a concrete, plain-language recommendation.
/// [lastTopWeightKg] is the added weight on the top working set last session
/// (0 for pure bodyweight work).
ProgressionSuggestion buildSuggestion(
  ProgressionModel model,
  ProgressionInput input, {
  required double lastTopWeightKg,
}) {
  final probs = model.predictProbs(input.base);
  final action = model.predict(input.base);
  final confidence = probs.reduce((a, b) => a > b ? a : b);
  final topReps = input.topRepsLast.round();
  final repLow = (input.repHigh.round() - _repRange).clamp(1, 1 << 30);
  final weighted = lastTopWeightKg > 0;

  switch (action) {
    case ProgressionAction.increase:
      if (weighted) {
        return ProgressionSuggestion(
          action: action,
          confidence: confidence,
          targetAddedWeightKg: lastTopWeightKg + _loadStep,
          targetReps: repLow,
          rationale:
              'You hit your target — add $_loadStep kg and rebuild reps.',
        );
      }
      return ProgressionSuggestion(
        action: action,
        confidence: confidence,
        targetReps: topReps + 1,
        rationale: "You're progressing well — aim for 1 more rep.",
      );
    case ProgressionAction.maintain:
      return ProgressionSuggestion(
        action: action,
        confidence: confidence,
        targetReps: topReps,
        targetAddedWeightKg: weighted ? lastTopWeightKg : null,
        rationale: 'One more solid session at this target to lock it in.',
      );
    case ProgressionAction.deload:
      if (weighted) {
        // Always reduce: at least one load step below the current weight (and
        // never below bodyweight), so the suggestion matches the "back off"
        // rationale even for light loads where 0.9x would round back up.
        final stepDown = lastTopWeightKg - _loadStep;
        final tenPctDown = lastTopWeightKg * 0.9;
        final reduced =
            math.max(0.0, _roundHalf(math.min(stepDown, tenPctDown)));
        return ProgressionSuggestion(
          action: action,
          confidence: confidence,
          targetAddedWeightKg: reduced,
          targetReps: repLow,
          rationale: 'Reps are slipping — back off the load this session.',
        );
      }
      return ProgressionSuggestion(
        action: action,
        confidence: confidence,
        targetReps: (topReps - 2).clamp(1, 1 << 30),
        rationale: 'Reps are slipping — ease off a couple reps and rebuild.',
      );
  }
}

/// The "Smart next target" suggestion for one exercise+target, or null when
/// there's no rep-based target or no history yet. Free feature (runs on-device).
final smartTargetProvider = FutureProvider.autoDispose
    .family<ProgressionSuggestion?, ({String exerciseId, int targetReps})>((
  ref,
  key,
) async {
  if (key.targetReps <= 0) return null;
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return null;
  final model = await ref.watch(progressionModelProvider.future);
  final workouts = await ref.watch(workoutRepositoryProvider).recent(uid);
  final input = buildProgressionInput(
    workouts,
    key.exerciseId,
    key.targetReps,
  );
  if (input == null) return null;
  // lastTopWeightKg is the top working set's load from the same session the
  // input was derived from — no second scan, no source-of-truth drift.
  return buildSuggestion(
    model,
    input,
    lastTopWeightKg: input.lastTopWeightKg,
  );
});
