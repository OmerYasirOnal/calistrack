import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../models/workout.dart';

/// Persists completed workouts and reads recent history
/// (`users/{uid}/workouts/{workoutId}`).
abstract interface class WorkoutRepository {
  /// Saves (or overwrites) a completed workout.
  Future<void> save(String uid, Workout workout);

  /// Recent workouts, newest first.
  Future<List<Workout>> recent(String uid, {int limit = 20});

  /// The sets logged for [exerciseId] in the most recent workout that
  /// contained it — drives the "last time" reference and set pre-fill.
  /// Empty when the exercise has never been logged.
  Future<List<LoggedSet>> lastSetsFor(String uid, String exerciseId);
}

class FirestoreWorkoutRepository implements WorkoutRepository {
  FirestoreWorkoutRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('workouts');

  @override
  Future<void> save(String uid, Workout workout) =>
      _col(uid).doc(workout.id).set(workout.toJson());

  @override
  Future<List<Workout>> recent(String uid, {int limit = 20}) async {
    final snap =
        await _col(uid).orderBy('date', descending: true).limit(limit).get();
    return snap.docs
        .map((d) => Workout.fromJson({'id': d.id, ...d.data()}))
        .toList();
  }

  @override
  Future<List<LoggedSet>> lastSetsFor(String uid, String exerciseId) async {
    final history = await recent(uid);
    for (final workout in history) {
      final logged =
          workout.exercises.firstWhereOrNull((e) => e.exerciseId == exerciseId);
      if (logged != null && logged.sets.isNotEmpty) return logged.sets;
    }
    return const [];
  }
}

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => FirestoreWorkoutRepository(ref.watch(firestoreProvider)),
);
