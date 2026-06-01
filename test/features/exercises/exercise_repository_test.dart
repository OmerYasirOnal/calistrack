import 'dart:convert';

import 'package:calistrack/features/exercises/data/exercise_repository.dart';
import 'package:calistrack/models/exercise.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// An [AssetBundle] that serves one fixed string for any key, so the loader can
/// be exercised without the real asset.
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

  group('ExerciseRepository (bundled asset)', () {
    test('loads the real library with well-formed entries', () async {
      final repo = ExerciseRepository();
      final all = await repo.all();

      expect(all, hasLength(19));
      expect(
        all.every((e) => e.id.isNotEmpty && e.name.isNotEmpty),
        isTrue,
        reason: 'every movement needs an id and a name',
      );
      // ids must be unique — they are used as lookup keys everywhere.
      expect(all.map((e) => e.id).toSet(), hasLength(all.length));
    });

    test('byId resolves a known movement and returns null otherwise', () async {
      final repo = ExerciseRepository();

      final pushUp = await repo.byId('push_up');
      expect(pushUp, isNotNull);
      expect(pushUp!.muscleGroup, MuscleGroup.push);
      expect(pushUp.type, ExerciseType.reps);

      expect(await repo.byId('not_a_real_id'), isNull);
    });

    test('caches the parsed list after the first load', () async {
      final repo = ExerciseRepository();
      final first = await repo.all();
      final second = await repo.all();
      expect(identical(first, second), isTrue);
    });
  });

  group('ExerciseRepository (injected bundle)', () {
    test('parses an injected fixture', () async {
      final fixture = json.encode([
        {
          'id': 'test_move',
          'name': 'Test Move',
          'muscleGroup': 'core',
          'type': 'hold',
          'description': 'fixture',
        },
      ]);
      final repo = ExerciseRepository(
        bundle: _FixtureBundle(fixture),
        assetPath: 'whatever.json',
      );

      final all = await repo.all();
      expect(all, hasLength(1));
      expect(all.single.id, 'test_move');
      expect(all.single.type, ExerciseType.hold);
      expect((await repo.byId('test_move'))!.name, 'Test Move');
    });
  });
}
