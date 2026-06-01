import 'dart:convert';

import 'package:calistrack/features/exercises/data/exercise_repository.dart';
import 'package:calistrack/features/programs/data/program_repository.dart';
import 'package:calistrack/models/exercise.dart';
import 'package:calistrack/models/program.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves one fixed JSON string for any key — lets us feed a deliberately
/// broken preset to the loader without a real asset.
class _FixtureBundle extends CachingAssetBundle {
  _FixtureBundle(this._payload);

  final String _payload;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(_payload));
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgramRepository (real presets)', () {
    test('parses every preset and resolves names from the library', () async {
      final library = await ExerciseRepository().all();
      final programs = await ProgramRepository().presets(library);

      expect(programs, hasLength(4));
      expect(
        programs.map((p) => p.id),
        containsAll(['classic_ppl', 'ppl_core', 'foundations', 'hybrid']),
      );

      final classic = programs.firstWhere((p) => p.id == 'classic_ppl');
      expect(classic.source, ProgramSource.preset);
      expect(classic.daysPerWeek, 3);

      // Names come from the library, never the JSON — and are never empty.
      final allMoves =
          programs.expand((p) => p.days).expand((d) => d.exercises);
      expect(allMoves.every((e) => e.name.isNotEmpty), isTrue);
    });

    test('preset-integrity: ids resolve and targets fit the movement type',
        () async {
      final library = await ExerciseRepository().all();
      final byId = {for (final e in library) e.id: e};

      // Parse the raw asset directly so this gate does NOT depend on the
      // repository's own resolution (which throws on bad ids) — it is the
      // real safety net for hand-authored presets.
      final raw = await rootBundle.loadString('assets/data/programs.json');
      final programs = (json.decode(raw) as List).cast<Map<String, dynamic>>();

      for (final program in programs) {
        final pid = program['id'];
        for (final day
            in (program['days'] as List).cast<Map<String, dynamic>>()) {
          for (final ex
              in (day['exercises'] as List).cast<Map<String, dynamic>>()) {
            final id = ex['exerciseId'] as String;
            final movement = byId[id];
            expect(movement, isNotNull, reason: 'unknown id "$id" in $pid');

            // the supplied target must match how the movement is measured...
            final requiredKey = switch (movement!.type) {
              ExerciseType.reps || ExerciseType.weightedReps => 'targetReps',
              ExerciseType.hold => 'targetHoldSeconds',
              ExerciseType.distance => 'targetDistanceMeters',
              ExerciseType.time => 'targetDurationSeconds',
            };
            // ...and be the ONLY target field, so targetSummary's precedence is
            // unambiguous and no target is ever silently dropped.
            const targetKeys = {
              'targetReps',
              'targetHoldSeconds',
              'targetDistanceMeters',
              'targetDurationSeconds',
            };
            final present = targetKeys.where(ex.containsKey).toSet();
            expect(
              present,
              {requiredKey},
              reason: '"$id" (${movement.type.name}) in $pid must carry only '
                  '$requiredKey, found $present',
            );
          }
        }
      }
    });

    test('hybrid Run day carries cardio targets', () async {
      final library = await ExerciseRepository().all();
      final programs = await ProgramRepository().presets(library);

      final run = programs
          .firstWhere((p) => p.id == 'hybrid')
          .days
          .firstWhere((d) => d.label == 'Run');
      final easyRun =
          run.exercises.firstWhere((e) => e.exerciseId == 'easy_run');
      expect(easyRun.targetDistanceMeters, isNotNull);
      final intervals =
          run.exercises.firstWhere((e) => e.exerciseId == 'intervals');
      expect(intervals.targetDurationSeconds, isNotNull);
    });
  });

  group('ProgramRepository (integrity failure)', () {
    test('throws StateError when a preset references an unknown id', () async {
      final library = await ExerciseRepository().all();
      final broken = json.encode([
        {
          'id': 'broken',
          'name': 'Broken',
          'days': [
            {
              'label': 'Push',
              'exercises': [
                {
                  'exerciseId': 'ghost_movement',
                  'targetSets': 3,
                  'targetReps': 5,
                },
              ],
            },
          ],
        },
      ]);
      final repo = ProgramRepository(
        bundle: _FixtureBundle(broken),
        assetPath: 'broken.json',
      );

      await expectLater(repo.presets(library), throwsStateError);
    });
  });
}
