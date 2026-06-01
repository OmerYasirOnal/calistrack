import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exercise.dart';

/// Tuning values for the logging loop — rest periods per movement type — loaded
/// from `assets/data/training_defaults.json` (no magic numbers in widgets).
class TrainingDefaults {
  const TrainingDefaults({
    required this.restSecondsByType,
    required this.defaultRestSeconds,
  });

  final Map<ExerciseType, int> restSecondsByType;
  final int defaultRestSeconds;

  /// Suggested rest after a set of [type] (0 means "no rest prompt").
  int restSecondsFor(ExerciseType type) =>
      restSecondsByType[type] ?? defaultRestSeconds;

  factory TrainingDefaults.fromJson(Map<String, dynamic> json) {
    final byType = (json['restSecondsByType'] as Map<String, dynamic>? ?? {});
    return TrainingDefaults(
      restSecondsByType: {
        for (final e in byType.entries)
          ExerciseType.fromName(e.key): (e.value as num).toInt(),
      },
      defaultRestSeconds: (json['defaultRestSeconds'] as num?)?.toInt() ?? 90,
    );
  }
}

class TrainingDefaultsRepository {
  TrainingDefaultsRepository({AssetBundle? bundle, String assetPath = _asset})
      : _bundle = bundle,
        _assetPath = assetPath;

  static const _asset = 'assets/data/training_defaults.json';

  final AssetBundle? _bundle;
  final String _assetPath;

  AssetBundle get _assets => _bundle ?? rootBundle;

  Future<TrainingDefaults> load() async {
    final raw = await _assets.loadString(_assetPath);
    return TrainingDefaults.fromJson(json.decode(raw) as Map<String, dynamic>);
  }
}

final trainingDefaultsProvider = FutureProvider<TrainingDefaults>(
  (ref) => TrainingDefaultsRepository().load(),
);
