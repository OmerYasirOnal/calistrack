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

  /// Stamps the one-time onboarding completion — a targeted merge that never
  /// rewrites the rest of the profile. Flips the router's `/onboarding` gate.
  Future<void> completeOnboarding(String uid, DateTime at);
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
  Future<void> completeOnboarding(String uid, DateTime at) => _doc(uid).set(
        {'onboardingCompletedAt': at.toIso8601String()},
        SetOptions(merge: true),
      );
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirestoreUserRepository(ref.watch(firestoreProvider)),
);
