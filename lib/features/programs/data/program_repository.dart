import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exercise.dart';
import '../../../models/program.dart';
import '../../exercises/data/exercise_repository.dart';

/// Loads the bundled preset programs (`assets/data/programs.json`).
///
/// Presets store only `exerciseId` + targets; each movement's display name is
/// resolved from the exercise library so there is a single source of truth and
/// names can never drift. A preset that references an unknown id is a build
/// error surfaced as a [StateError] (guarded by the preset-integrity test).
class ProgramRepository {
  ProgramRepository({AssetBundle? bundle, String assetPath = _defaultAsset})
      : _bundle = bundle,
        _assetPath = assetPath;

  static const _defaultAsset = 'assets/data/programs.json';

  final AssetBundle? _bundle;
  final String _assetPath;

  AssetBundle get _assets => _bundle ?? rootBundle;

  /// Preset programs, with movement names resolved from [library].
  Future<List<Program>> presets(List<Exercise> library) async {
    final byId = {for (final e in library) e.id: e};
    final raw = await _assets.loadString(_assetPath);
    final decoded = json.decode(raw) as List<dynamic>;
    return decoded
        .map((p) => _program(p as Map<String, dynamic>, byId))
        .toList(growable: false);
  }

  Program _program(Map<String, dynamic> json, Map<String, Exercise> byId) =>
      Program(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        source: ProgramSource.preset,
        days: (json['days'] as List<dynamic>? ?? [])
            .map((d) => _day(d as Map<String, dynamic>, byId))
            .toList(),
      );

  ProgramDay _day(Map<String, dynamic> json, Map<String, Exercise> byId) =>
      ProgramDay(
        label: json['label'] as String,
        exercises: (json['exercises'] as List<dynamic>? ?? [])
            .map((e) => _exercise(e as Map<String, dynamic>, byId))
            .toList(),
      );

  ProgramExercise _exercise(
    Map<String, dynamic> json,
    Map<String, Exercise> byId,
  ) {
    final id = json['exerciseId'] as String;
    final exercise = byId[id];
    if (exercise == null) {
      throw StateError('Preset references unknown exercise id "$id"');
    }
    return ProgramExercise(
      exerciseId: id,
      name: exercise.name,
      targetSets: (json['targetSets'] as num?)?.toInt() ?? 3,
      targetReps: (json['targetReps'] as num?)?.toInt(),
      targetHoldSeconds: (json['targetHoldSeconds'] as num?)?.toInt(),
      targetDistanceMeters: (json['targetDistanceMeters'] as num?)?.toInt(),
      targetDurationSeconds: (json['targetDurationSeconds'] as num?)?.toInt(),
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// The repository singleton (overridable in tests).
final programRepositoryProvider = Provider<ProgramRepository>(
  (ref) => ProgramRepository(),
);

/// Preset programs as an [AsyncValue], names resolved against the live library.
final presetProgramsProvider = FutureProvider<List<Program>>((ref) async {
  final library = await ref.watch(exerciseLibraryProvider.future);
  return ref.watch(programRepositoryProvider).presets(library);
});
