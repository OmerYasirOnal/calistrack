import 'dart:convert';

import 'package:calistrack/features/exercises/data/exercise_repository.dart';
import 'package:calistrack/features/programs/data/program_repository.dart';
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

    test('preset-integrity: every exerciseId exists in the library', () async {
      final library = await ExerciseRepository().all();
      final libraryIds = library.map((e) => e.id).toSet();
      final programs = await ProgramRepository().presets(library);

      final referenced = programs
          .expand((p) => p.days)
          .expand((d) => d.exercises)
          .map((e) => e.exerciseId);
      for (final id in referenced) {
        expect(
          libraryIds,
          contains(id),
          reason: 'preset references unknown exercise "$id"',
        );
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
