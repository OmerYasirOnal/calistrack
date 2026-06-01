import 'dart:async';

import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/features/workout/data/workout_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:calistrack/models/workout.dart';
import 'package:collection/collection.dart';

/// In-memory [AuthRepository] for tests. Emits an initial user (or null) and
/// records calls so behaviour can be asserted without Firebase.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? initialUser, this.initialDelay = Duration.zero})
      : _current = initialUser;

  AppUser? _current;

  /// Simulates the real async gap before Firebase restores the auth state.
  final Duration initialDelay;
  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();

  /// When set, the next sign-in/register/google call throws this.
  Object? errorToThrow;
  int signInCalls = 0;
  int registerCalls = 0;
  int googleCalls = 0;
  int signOutCalls = 0;

  void dispose() => _controller.close();

  void _set(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    if (initialDelay > Duration.zero) await Future<void>.delayed(initialDelay);
    yield _current;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _current;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    _set(AppUser(uid: 'uid_$email', email: email));
  }

  @override
  Future<void> registerWithEmail({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    registerCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    _set(AppUser(uid: 'uid_$email', email: email, displayName: displayName));
  }

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    _set(const AppUser(uid: 'uid_google', email: 'google@example.com'));
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _set(null);
  }
}

/// In-memory [UserRepository] for tests. `watch` is backed by a broadcast
/// stream so updates (e.g. setActiveProgram) are observed live.
class FakeUserRepository implements UserRepository {
  final Map<String, AppUser> store = {};
  int ensureCalls = 0;
  int setActiveCalls = 0;

  final Map<String, StreamController<AppUser?>> _controllers = {};

  StreamController<AppUser?> _controllerFor(String uid) =>
      _controllers.putIfAbsent(
        uid,
        () => StreamController<AppUser?>.broadcast(),
      );

  void _emit(String uid) => _controllerFor(uid).add(store[uid]);

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
  }

  @override
  Future<AppUser?> fetch(String uid) async => store[uid];

  @override
  Stream<AppUser?> watch(String uid) async* {
    yield store[uid];
    yield* _controllerFor(uid).stream;
  }

  @override
  Future<void> upsert(AppUser user) async {
    store[user.uid] = user;
    _emit(user.uid);
  }

  @override
  Future<AppUser> ensureProfile(AppUser authUser) async {
    ensureCalls++;
    final user = store.putIfAbsent(authUser.uid, () => authUser);
    _emit(authUser.uid);
    return user;
  }

  @override
  Future<void> setActiveProgram(String uid, String? programId) async {
    setActiveCalls++;
    final base =
        store[uid] ?? AppUser(uid: uid, email: 'test_$uid@example.com');
    // Constructed explicitly (not copyWith) so a null programId truly *clears*
    // the active program — mirroring the Firestore merge write.
    store[uid] = AppUser(
      uid: base.uid,
      email: base.email,
      displayName: base.displayName,
      heightCm: base.heightCm,
      weightKg: base.weightKg,
      level: base.level,
      goals: base.goals,
      activeProgramId: programId,
    );
    _emit(uid);
  }
}

/// In-memory [WorkoutRepository] for tests. Records saves and serves a
/// configurable last-sets map.
class FakeWorkoutRepository implements WorkoutRepository {
  final List<Workout> saved = [];
  final Map<String, List<LoggedSet>> lastSets = {};

  @override
  Future<void> save(String uid, Workout workout) async => saved.add(workout);

  @override
  Future<List<Workout>> recent(String uid, {int limit = 20}) async {
    final sorted = [...saved]..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<LoggedSet>> lastSetsFor(String uid, String exerciseId) async {
    if (lastSets.containsKey(exerciseId)) return lastSets[exerciseId]!;
    for (final w in await recent(uid)) {
      final logged =
          w.exercises.firstWhereOrNull((e) => e.exerciseId == exerciseId);
      if (logged != null && logged.sets.isNotEmpty) return logged.sets;
    }
    return const [];
  }
}
