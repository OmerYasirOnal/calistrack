import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/exercise.dart';
import '../../../models/program.dart';
import '../../auth/data/auth_repository.dart';
import '../../exercises/data/exercise_repository.dart';
import '../../profile/data/user_repository.dart';
import '../data/program_repository.dart';
import '../data/user_program_repository.dart';

/// The inputs for AI program generation.
class GenerationRequest {
  const GenerationRequest({
    required this.level,
    required this.daysPerWeek,
    this.goals = const [],
    this.equipment = const [],
  });

  final ExperienceLevel level;
  final int daysPerWeek;
  final List<String> goals;
  final List<String> equipment;

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'daysPerWeek': daysPerWeek,
        'goals': goals,
        'equipment': equipment,
      };
}

class GenerationResult {
  const GenerationResult({required this.program, required this.usedFallback});

  final Program program;

  /// True when the local template was used (the function was unavailable).
  final bool usedFallback;
}

typedef GenerateCaller = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> request,
);

/// Produces a tailored program — via the `generateProgram` Cloud Function when
/// it's reachable, otherwise a deterministic local fallback so the flow always
/// succeeds. Movement names are resolved from the bundled library (the function
/// returns ids + targets only), matching the preset pipeline.
class AiProgramService {
  AiProgramService({GenerateCaller? caller})
      : _caller = caller ?? _callFunction;

  final GenerateCaller _caller;

  Future<GenerationResult> generate(
    GenerationRequest request, {
    required List<Exercise> library,
    required List<Program> presets,
  }) async {
    try {
      final raw = await _caller(request.toJson());
      return GenerationResult(
        program: _toProgram(raw, library),
        usedFallback: false,
      );
    } on Exception catch (_) {
      // Only fall back on *expected* failures (function unavailable, bad
      // response). Programming Errors (e.g. a bad cast) propagate so they are
      // never silently masked as a "fallback".
      return GenerationResult(
        program: fallbackProgram(request, presets),
        usedFallback: true,
      );
    }
  }

  Program _toProgram(Map<String, dynamic> raw, List<Exercise> library) {
    final byId = {for (final e in library) e.id: e};
    // Nested values from cloud_functions arrive as Map<Object?, Object?> on a
    // real device (StandardMessageCodec) — read them as plain Map, never cast
    // to Map<String, dynamic>.
    final days = ((raw['days'] as List?) ?? const [])
        .map((d) => d as Map)
        .map((d) {
          final exercises = ((d['exercises'] as List?) ?? const [])
              .map((e) => e as Map)
              .where((e) => byId.containsKey(e['exerciseId']))
              .map((e) {
            final movement = byId[e['exerciseId']]!;
            return ProgramExercise(
              exerciseId: movement.id,
              name: movement.name,
              targetSets: (e['targetSets'] as num?)?.toInt() ?? 3,
              targetReps: (e['targetReps'] as num?)?.toInt(),
              targetHoldSeconds: (e['targetHoldSeconds'] as num?)?.toInt(),
              targetDistanceMeters:
                  (e['targetDistanceMeters'] as num?)?.toInt(),
              targetDurationSeconds:
                  (e['targetDurationSeconds'] as num?)?.toInt(),
            );
          }).toList();
          return ProgramDay(
            label: d['label'] as String? ?? 'Day',
            exercises: exercises,
          );
        })
        .where((day) => day.exercises.isNotEmpty)
        .toList();

    if (days.isEmpty) {
      throw const FormatException('Generated program had no usable days.');
    }
    return Program(
      id: 'gen_${DateTime.now().millisecondsSinceEpoch}',
      name: raw['name'] as String? ?? 'AI Program',
      description: raw['description'] as String? ?? '',
      source: ProgramSource.ai,
      days: days,
      createdAt: DateTime.now(),
    );
  }
}

/// Deterministic local fallback: the preset matching the requested days/week,
/// else Foundations, renamed to the user's intent. Never throws.
Program fallbackProgram(GenerationRequest request, List<Program> presets) {
  final base =
      presets.firstWhereOrNull((p) => p.daysPerWeek == request.daysPerWeek) ??
          presets.firstWhereOrNull((p) => p.id == 'foundations') ??
          (presets.isNotEmpty
              ? presets.first
              : const Program(id: 'empty', name: 'Plan', days: []));
  final goal = request.goals.isNotEmpty ? request.goals.first : 'custom';
  // One fallback per cadence (id keyed on daysPerWeek): regenerating for the
  // same days/week replaces the prior fallback rather than piling up clones.
  return base.copyWith(
    id: 'gen_fallback_${request.daysPerWeek}',
    name: 'Your $goal plan',
    source: ProgramSource.custom,
  );
}

Future<Map<String, dynamic>> _callFunction(
  Map<String, dynamic> request,
) async {
  final callable = FirebaseFunctions.instance.httpsCallable('generateProgram');
  final result = await callable.call<Object?>(request);
  return Map<String, dynamic>.from(result.data as Map);
}

final aiProgramServiceProvider =
    Provider<AiProgramService>((ref) => AiProgramService());

/// Drives the generate → preview → save flow. State holds the previewed
/// [GenerationResult] (null before the first generation).
class AiGenerationController
    extends AutoDisposeAsyncNotifier<GenerationResult?> {
  @override
  FutureOr<GenerationResult?> build() => null;

  Future<void> generate(GenerationRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final library = await ref.read(exerciseLibraryProvider.future);
      final presets = await ref.read(presetProgramsProvider.future);
      return ref
          .read(aiProgramServiceProvider)
          .generate(request, library: library, presets: presets);
    });
  }

  /// Persists [program] to the user's collection and makes it active.
  Future<void> save(Program program) async {
    final uid = (await ref.read(authStateProvider.future))?.uid;
    if (uid == null) throw StateError('Cannot save while signed out.');
    await ref.read(userProgramRepositoryProvider).saveProgram(uid, program);
    await ref.read(userRepositoryProvider).setActiveProgram(uid, program.id);
  }
}

final aiGenerationControllerProvider =
    AutoDisposeAsyncNotifierProvider<AiGenerationController, GenerationResult?>(
  AiGenerationController.new,
);
