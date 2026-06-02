import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../models/app_user.dart';

/// CRUD for the `users/{uid}` profile document.
abstract interface class UserRepository {
  Future<AppUser?> fetch(String uid);

  Stream<AppUser?> watch(String uid);

  Future<void> upsert(AppUser user);

  /// Creates the profile doc on first login if it does not already exist,
  /// returning the persisted profile (existing or freshly created).
  Future<AppUser> ensureProfile(AppUser authUser);

  /// Sets (or clears, when null) the user's active program — a targeted merge
  /// that never rewrites the rest of the profile.
  Future<void> setActiveProgram(String uid, String? programId);

  /// Stamps the one-time onboarding completion and persists the captured
  /// profile answers in a single targeted merge (never rewrites the rest of the
  /// profile). Flips the router's `/onboarding` gate. Answer fields are optional
  /// so the same call serves both the minimal flow and the full About-You flow.
  Future<void> completeOnboarding(
    String uid,
    DateTime at, {
    ExperienceLevel? level,
    List<String>? goals,
    double? heightCm,
    double? weightKg,
  });

  /// Saves the user-editable profile details (name/level/goals/body stats) in a
  /// targeted merge. Body stats are written even when null so they can be
  /// cleared. Never touches `activeProgramId` / `onboardingCompletedAt`.
  Future<void> updateDetails(
    String uid, {
    required String displayName,
    required ExperienceLevel level,
    required List<String> goals,
    double? heightCm,
    double? weightKg,
  });
}

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<AppUser?> fetch(String uid) async {
    final snap = await _doc(uid).get();
    final data = snap.data();
    return data == null ? null : AppUser.fromJson({'uid': uid, ...data});
  }

  @override
  Stream<AppUser?> watch(String uid) => _doc(uid).snapshots().map((snap) {
        final data = snap.data();
        return data == null ? null : AppUser.fromJson({'uid': uid, ...data});
      });

  @override
  Future<void> upsert(AppUser user) =>
      _doc(user.uid).set(user.toJson(), SetOptions(merge: true));

  @override
  Future<AppUser> ensureProfile(AppUser authUser) async {
    final existing = await fetch(authUser.uid);
    if (existing != null) return existing;
    await upsert(authUser);
    return authUser;
  }

  @override
  Future<void> setActiveProgram(String uid, String? programId) => _doc(uid).set(
        {'activeProgramId': programId},
        SetOptions(merge: true),
      );

  @override
  Future<void> completeOnboarding(
    String uid,
    DateTime at, {
    ExperienceLevel? level,
    List<String>? goals,
    double? heightCm,
    double? weightKg,
  }) =>
      _doc(uid).set(
        {
          'onboardingCompletedAt': at.toIso8601String(),
          if (level != null) 'level': level.name,
          if (goals != null) 'goals': goals,
          if (heightCm != null) 'heightCm': heightCm,
          if (weightKg != null) 'weightKg': weightKg,
        },
        SetOptions(merge: true),
      );

  @override
  Future<void> updateDetails(
    String uid, {
    required String displayName,
    required ExperienceLevel level,
    required List<String> goals,
    double? heightCm,
    double? weightKg,
  }) =>
      _doc(uid).set(
        {
          'displayName': displayName,
          'level': level.name,
          'goals': goals,
          // Written even when null so the user can clear a body stat.
          'heightCm': heightCm,
          'weightKg': weightKg,
        },
        SetOptions(merge: true),
      );
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirestoreUserRepository(ref.watch(firestoreProvider)),
);
