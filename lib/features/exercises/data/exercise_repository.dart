import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exercise.dart';

/// Loads the bundled, read-only exercise library
/// (`assets/data/exercises.json`). The library is static seed data, so it lives
/// in assets — no Firestore read, works offline and at zero cost.
///
/// The [AssetBundle] is injectable so tests can supply a fixture without
/// depending on the real asset.
class ExerciseRepository {
  ExerciseRepository({AssetBundle? bundle, String assetPath = _defaultAsset})
      : _bundle = bundle,
        _assetPath = assetPath;

  static const _defaultAsset = 'assets/data/exercises.json';

  final AssetBundle? _bundle;
  final String _assetPath;

  List<Exercise>? _cache;
  Future<List<Exercise>>? _loading;

  AssetBundle get _assets => _bundle ?? rootBundle;

  /// Every movement in the library, cached after the first load. The in-flight
  /// future is memoized so concurrent first calls share one parse (and the
  /// cached list keeps a stable identity).
  Future<List<Exercise>> all() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    return _loading ??= _load();
  }

  Future<List<Exercise>> _load() async {
    final raw = await _assets.loadString(_assetPath);
    // The library is a trusted, build-time-validated asset; a malformed payload
    // surfaces as an AsyncError through the provider rather than crashing.
    final decoded = json.decode(raw) as List<dynamic>;
    final exercises = decoded
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    _cache = exercises;
    return exercises;
  }

  /// The movement with [id], or `null` when the library has no such id.
  Future<Exercise?> byId(String id) async {
    final exercises = await all();
    return exercises.firstWhereOrNull((e) => e.id == id);
  }
}

/// The repository singleton (overridable in tests).
final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(),
);

/// The full exercise library as an [AsyncValue] for widgets to watch.
final exerciseLibraryProvider = FutureProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).all(),
);
