import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../models/program.dart';
import '../../auth/data/auth_repository.dart';

/// Persists and reads the user's own programs (AI-generated / custom) at
/// `users/{uid}/programs/{programId}`. Presets stay in assets; this is the
/// mutable, per-user collection.
abstract interface class UserProgramRepository {
  Future<void> saveProgram(String uid, Program program);

  Stream<List<Program>> watch(String uid);
}

class FirestoreUserProgramRepository implements UserProgramRepository {
  FirestoreUserProgramRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('programs');

  @override
  Future<void> saveProgram(String uid, Program program) =>
      _col(uid).doc(program.id).set(program.toJson());

  @override
  Stream<List<Program>> watch(String uid) => _col(uid).snapshots().map(
        (snap) => snap.docs
            .map((d) => Program.fromJson({'id': d.id, ...d.data()}))
            .toList(),
      );
}

final userProgramRepositoryProvider = Provider<UserProgramRepository>(
  (ref) => FirestoreUserProgramRepository(ref.watch(firestoreProvider)),
);

/// The user's saved programs, live. Empty when signed out.
final userProgramsProvider = StreamProvider<List<Program>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(userProgramRepositoryProvider).watch(uid);
});
