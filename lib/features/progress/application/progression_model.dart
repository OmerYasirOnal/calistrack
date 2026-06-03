import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The next-session action the model recommends for one exercise.
enum ProgressionAction { deload, maintain, increase }

/// The 6 base features the model consumes, computed from logged history.
/// Mirrors `tools/ml/generate_and_train.py` (BASE_FEATURE_NAMES) exactly.
class ProgressionInput {
  const ProgressionInput({
    required this.topRepsLast,
    required this.repHigh,
    required this.sessionsAtTop,
    required this.trend3,
    required this.avgRir,
    this.lastTopWeightKg = 0,
  });

  final double topRepsLast;
  final double repHigh;
  final double sessionsAtTop;
  final double trend3;
  final double avgRir;

  /// The added weight on the top working set last session (0 = bodyweight).
  /// Context for the suggestion's load math — NOT a model feature, so it is
  /// deliberately excluded from [base].
  final double lastTopWeightKg;

  double get margin => topRepsLast - repHigh;

  /// Base-6 feature vector in the trained order.
  List<double> get base =>
      [topRepsLast, repHigh, margin, sessionsAtTop, trend3, avgRir];
}

/// A concrete, user-facing recommendation derived from the model's action.
class ProgressionSuggestion {
  const ProgressionSuggestion({
    required this.action,
    required this.confidence,
    required this.rationale,
    this.targetReps,
    this.targetAddedWeightKg,
  });

  final ProgressionAction action;

  /// Model confidence in [action] (max softmax probability, 0..1).
  final double confidence;
  final String rationale;
  final int? targetReps;
  final double? targetAddedWeightKg;
}

/// Tiny on-device progression model: multinomial logistic regression over
/// standardized features, run as a dot-product + softmax. Pure Dart — no native
/// deps, works on web, $0, offline. Built from the weights exported by
/// `tools/ml/generate_and_train.py`; falls back to the rule-based heuristic
/// (the model's training oracle) when no weights are available.
class ProgressionModel {
  ProgressionModel._({
    this.mean,
    this.std,
    this.coef,
    this.intercept,
  });

  /// A weights-backed model. Throws [FormatException] on a malformed map.
  factory ProgressionModel.fromJson(Map<String, dynamic> json) {
    List<double> nums(Object? v) =>
        (v as List).map((e) => (e as num).toDouble()).toList();
    return ProgressionModel._(
      mean: nums(json['mean']),
      std: nums(json['std']),
      coef: (json['coef'] as List).map((row) => nums(row)).toList(),
      intercept: nums(json['intercept']),
    );
  }

  /// A weights-free model that uses the rule-based heuristic only.
  factory ProgressionModel.heuristic() => ProgressionModel._();

  final List<double>? mean;
  final List<double>? std;
  final List<List<double>>? coef; // 3 x 11
  final List<double>? intercept; // 3

  bool get usesWeights => coef != null;

  /// base-6 -> 11 features (base + soft interactions). Must match the Python
  /// `featurize()` exactly.
  static List<double> featurize(List<double> base) {
    final margin = base[2];
    final trend3 = base[4];
    final rir = base[5];
    double relu(double x) => x > 0 ? x : 0;
    final grind = relu(1.0 - rir);
    final decline = relu(-trend3);
    return [
      ...base,
      grind,
      decline,
      grind * decline,
      relu(margin) * relu(rir - 0.5),
      relu(-margin) * relu(rir - 1.5),
    ];
  }

  /// Class probabilities [DELOAD, MAINTAIN, INCREASE] for a base-6 input.
  /// Weights path: standardize -> z=W.x+b -> softmax. Heuristic path: one-hot.
  List<double> predictProbs(List<double> base) {
    final w = coef;
    if (w == null) {
      final idx = _heuristicAction(base).index;
      return [for (var i = 0; i < 3; i++) i == idx ? 1.0 : 0.0];
    }
    final x = featurize(base);
    final m = mean!, s = std!, b = intercept!;
    final z = List<double>.filled(w.length, 0);
    for (var k = 0; k < w.length; k++) {
      var acc = b[k];
      for (var i = 0; i < x.length; i++) {
        acc += w[k][i] * ((x[i] - m[i]) / s[i]);
      }
      z[k] = acc;
    }
    final maxZ = z.reduce(math.max);
    var sum = 0.0;
    final exp = [for (final v in z) math.exp(v - maxZ)];
    for (final e in exp) {
      sum += e;
    }
    return [for (final e in exp) e / sum];
  }

  ProgressionAction predict(List<double> base) {
    final probs = predictProbs(base);
    var best = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[best]) best = i;
    }
    return ProgressionAction.values[best];
  }

  /// The training oracle, reimplemented for the no-weights fallback. Mirrors
  /// `heuristic_label` in the Python trainer.
  static ProgressionAction _heuristicAction(List<double> base) {
    final topReps = base[0], repHigh = base[1];
    final sessionsAtTop = base[3], trend3 = base[4], avgRir = base[5];
    final margin = topReps - repHigh;
    if (trend3 <= -1.0 && avgRir <= 0.5) return ProgressionAction.deload;
    if (margin < 0 && avgRir >= 2.0 && trend3 >= 0.0) {
      return ProgressionAction.increase;
    }
    if (margin >= 0 && sessionsAtTop >= 1 && avgRir >= 1.0) {
      return ProgressionAction.increase;
    }
    return ProgressionAction.maintain;
  }
}

/// The asset that carries the trained weights (see `tools/ml`).
const progressionModelAsset = 'assets/data/progression_model.json';

/// Loads the on-device model from the bundled asset, falling back to the
/// heuristic-only model if the asset is missing or malformed.
final progressionModelProvider = FutureProvider<ProgressionModel>((ref) async {
  try {
    final raw = await rootBundle.loadString(progressionModelAsset);
    return ProgressionModel.fromJson(json.decode(raw) as Map<String, dynamic>);
  } catch (_) {
    return ProgressionModel.heuristic();
  }
});
