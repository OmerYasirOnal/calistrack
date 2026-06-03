import 'dart:convert';
import 'dart:io';

import 'package:calistrack/features/progress/application/progression_model.dart';
import 'package:calistrack/features/progress/application/smart_target.dart';
import 'package:calistrack/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgressionModel parity with the Python trainer', () {
    late ProgressionModel model;
    late List<dynamic> golden;

    setUpAll(() {
      final m = json.decode(
        File('assets/data/progression_model.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      model = ProgressionModel.fromJson(m);
      golden = json.decode(
        File('tools/ml/golden_cases.json').readAsStringSync(),
      ) as List<dynamic>;
    });

    test('reproduces softmax probabilities + argmax for every golden case', () {
      expect(golden, isNotEmpty);
      for (final raw in golden) {
        final c = raw as Map<String, dynamic>;
        final base = (c['baseFeatures'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
        final expected =
            (c['probs'] as List).map((e) => (e as num).toDouble()).toList();
        final got = model.predictProbs(base);
        for (var i = 0; i < 3; i++) {
          expect(got[i], closeTo(expected[i], 1e-4),
              reason: 'prob[$i] for base $base');
        }
        expect(model.predict(base).index, c['predicted']);
      }
    });
  });

  group('featurize', () {
    test('matches the documented base + interaction derivation', () {
      // [top, repHigh, margin, sessionsAtTop, trend3, rir]
      final f = ProgressionModel.featurize([12, 10, 2, 2, 1, 2]);
      expect(f.length, 11);
      expect(f[6], 0); // grind  = relu(1-2)
      expect(f[7], 0); // decline= relu(-1)
      expect(f[8], 0); // deload_and
      expect(f[9], closeTo(3.0, 1e-9)); // ready_load = relu(2)*relu(1.5)
      expect(f[10], 0); // ready_reps = relu(-2)*...
    });
  });

  group('heuristic fallback (no weights)', () {
    final m = ProgressionModel.heuristic();
    test('deload when declining and grinding', () {
      expect(m.predict([8, 10, -2, 0, -2.0, 0.0]), ProgressionAction.deload);
    });
    test('increase when at range top with reps in reserve', () {
      expect(m.predict([11, 10, 1, 2, 0.5, 2.0]), ProgressionAction.increase);
    });
    test('maintain otherwise', () {
      expect(m.predict([9, 10, -1, 0, 0.0, 1.0]), ProgressionAction.maintain);
    });
    test('predictProbs is one-hot', () {
      expect(m.predictProbs([8, 10, -2, 0, -2.0, 0.0]), [1.0, 0.0, 0.0]);
    });
  });

  group('buildProgressionInput', () {
    Workout wk(String id, int d, List<LoggedSet> sets) => Workout(
          id: id,
          date: DateTime(2026, 5, d),
          dayLabel: 'Push',
          exercises: [
            LoggedExercise(exerciseId: 'push_up', name: 'Push-up', sets: sets),
          ],
        );

    test('extracts features from newest-first history', () {
      final hist = [
        wk('w3', 30, [const LoggedSet(reps: 12), const LoggedSet(reps: 11)]),
        wk('w2', 27, [const LoggedSet(reps: 11), const LoggedSet(reps: 10)]),
        wk('w1', 24, [const LoggedSet(reps: 10), const LoggedSet(reps: 9)]),
      ];
      final input = buildProgressionInput(hist, 'push_up', 10)!;
      expect(input.topRepsLast, 12);
      expect(input.repHigh, 10);
      expect(input.margin, 2);
      expect(input.sessionsAtTop, 3); // all top-sets >= 10
      expect(input.trend3, closeTo(1.0, 1e-9)); // (12-10)/2
      expect(input.avgRir, 2.0); // default (none logged)
    });

    test('returns null when no history for the exercise', () {
      expect(buildProgressionInput(const [], 'push_up', 10), isNull);
    });

    test('uses logged RIR and counts a single session as flat trend', () {
      final hist = [
        wk('w1', 30, [
          const LoggedSet(reps: 8, rir: 1),
          const LoggedSet(reps: 8, rir: 3),
        ]),
      ];
      final input = buildProgressionInput(hist, 'push_up', 10)!;
      expect(input.avgRir, 2.0); // (1+3)/2
      expect(input.sessionsAtTop, 0); // 8 < 10
      expect(input.trend3, 0); // single session
    });
  });

  group('buildSuggestion', () {
    final m = ProgressionModel.heuristic();

    test('increase, bodyweight -> aim for +1 rep', () {
      const input = ProgressionInput(
          topRepsLast: 11, repHigh: 10, sessionsAtTop: 2, trend3: 0.5, avgRir: 2);
      final s = buildSuggestion(m, input, lastTopWeightKg: 0);
      expect(s.action, ProgressionAction.increase);
      expect(s.targetReps, 12);
      expect(s.targetAddedWeightKg, isNull);
    });

    test('increase, weighted -> +2.5 kg', () {
      const input = ProgressionInput(
          topRepsLast: 11, repHigh: 10, sessionsAtTop: 2, trend3: 0.5, avgRir: 2);
      final s = buildSuggestion(m, input, lastTopWeightKg: 10);
      expect(s.action, ProgressionAction.increase);
      expect(s.targetAddedWeightKg, 12.5);
      expect(s.targetReps, 6); // rep range bottom (10-4)
    });

    test('deload, bodyweight -> ease off two reps', () {
      const input = ProgressionInput(
          topRepsLast: 8, repHigh: 10, sessionsAtTop: 0, trend3: -2, avgRir: 0);
      final s = buildSuggestion(m, input, lastTopWeightKg: 0);
      expect(s.action, ProgressionAction.deload);
      expect(s.targetReps, 6);
    });

    test('confidence is 1.0 for the heuristic model', () {
      const input = ProgressionInput(
          topRepsLast: 9, repHigh: 10, sessionsAtTop: 0, trend3: 0, avgRir: 1);
      final s = buildSuggestion(m, input, lastTopWeightKg: 0);
      expect(s.confidence, 1.0);
      expect(s.action, ProgressionAction.maintain);
    });
  });
}
