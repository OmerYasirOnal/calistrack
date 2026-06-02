import 'dart:async';

import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/features/programs/data/user_program_repository.dart';
import 'package:calistrack/features/skills/data/skill_repository.dart';
import 'package:calistrack/features/workout/data/workout_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:calistrack/models/program.dart';
import 'package:calistrack/models/skill_progress.dart';
import 'package:calistrack/models/workout.dart';
import 'package:collection/collection.dart';

/// A signed-in, already-onboarded user for tests that exercise the
/// post-onboarding app (Today/Programs/Skills). The onboarding flag is set so
/// the router's gate doesn't divert these tests to `/onboarding` — only the
/// onboarding-specific tests deliberately leave it null.
AppUser onboardedUser({
  String uid = 'u1',
  String email = 'a@b.com',
  String? activeProgramId,
}) =>
    AppUser(
      uid: uid,
      email: email,
      activeProgramId: activeProgramId,
      onboardingCompletedAt: DateTime(2026, 1, 1),
    );

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
  int resetCalls = 0;
  String? lastResetEmail;
  int verifyCalls = 0;

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

  int anonymousCalls = 0;
  int linkCalls = 0;

  @override
  Future<void> signInAnonymously() async {
    anonymousCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    _set(const AppUser(uid: 'uid_guest', email: '', isAnonymous: true));
  }

  @override
  Future<void> linkEmailPassword({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    linkCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    // Same uid as the guest — mirrors Firebase linkWithCredential keeping the uid.
    _set(
      AppUser(
        uid: _current?.uid ?? 'uid_guest',
        email: email,
        displayName: displayName,
      ),
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetCalls++;
    lastResetEmail = email;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> sendEmailVerification() async {
    verifyCalls++;
    if (errorToThrow != null) throw errorToThrow!;
  }

  int updateNameCalls = 0;

  @override
  Future<void> updateDisplayName(String displayName) async {
    updateNameCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    if (_current != null) _set(_current!.copyWith(displayName: displayName));
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
  int completeOnboardingCalls = 0;

  final Map<String, StreamController<AppUser?>> _controllers = {};

  StreamController<AppUser?> _controllerFor(String uid) =>
      _controllers.putIfAbsent(
        uid,
        () => StreamController<AppUser?>.broadcast(),
      );

  void _emit(String uid) => _controllerFor(uid).add(store[uid]);

  /// Applies a targeted merge to the stored profile and emits it — the in-memory
  /// analogue of a Firestore `set(.., merge: true)`. Overrides are layered on top
  /// of the existing doc's JSON, so unwritten fields are preserved and an
  /// explicit `null` override clears its field (which `copyWith` can't express).
  void _merge(String uid, Map<String, dynamic> overrides) {
    final base =
        store[uid] ?? AppUser(uid: uid, email: 'test_$uid@example.com');
    store[uid] = AppUser.fromJson({...base.toJson(), ...overrides});
    _emit(uid);
  }

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
    _merge(uid, {'activeProgramId': programId});
  }

  @override
  Future<void> completeOnboarding(
    String uid,
    DateTime at, {
    ExperienceLevel? level,
    List<String>? goals,
    double? heightCm,
    double? weightKg,
  }) async {
    completeOnboardingCalls++;
    final base =
        store[uid] ?? AppUser(uid: uid, email: 'test_$uid@example.com');
    store[uid] = base.copyWith(
      onboardingCompletedAt: at,
      level: level,
      goals: goals,
      heightCm: heightCm,
      weightKg: weightKg,
    );
    _emit(uid);
  }

  int updateDetailsCalls = 0;

  @override
  Future<void> updateDetails(
    String uid, {
    required String displayName,
    required ExperienceLevel level,
    required List<String> goals,
    double? heightCm,
    double? weightKg,
  }) async {
    updateDetailsCalls++;
    // Body stats are written even when null so they clear, matching the real
    // targeted merge; the merge helper preserves everything else.
    _merge(uid, {
      'displayName': displayName,
      'level': level.name,
      'goals': goals,
      'heightCm': heightCm,
      'weightKg': weightKg,
    });
  }

  int setReminderCalls = 0;

  @override
  Future<void> setReminder(
    String uid, {
    required bool enabled,
    int? minutes,
  }) async {
    setReminderCalls++;
    _merge(uid, {'reminderEnabled': enabled, 'reminderMinutes': minutes});
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

/// In-memory [SkillRepository] for tests — preset trees plus a live merge of
/// recorded progress.
class FakeSkillRepository implements SkillRepository {
  FakeSkillRepository(this._presets);

  final List<SkillProgress> _presets;
  final Map<String, SavedSkill> saved = {};
  final StreamController<List<SkillProgress>> _controller =
      StreamController<List<SkillProgress>>.broadcast();

  int logCalls = 0;
  int setStepCalls = 0;

  void dispose() => _controller.close();

  void _emit() => _controller.add(mergeSkills(_presets, saved));

  @override
  Future<List<SkillProgress>> presets() async => _presets;

  @override
  Stream<List<SkillProgress>> watch(String uid) async* {
    yield mergeSkills(_presets, saved);
    yield* _controller.stream;
  }

  @override
  Future<void> logAttempt(String uid, String skillId, SkillLog log) async {
    logCalls++;
    final cur = saved[skillId] ?? (currentStepIndex: 0, logs: <SkillLog>[]);
    saved[skillId] =
        (currentStepIndex: cur.currentStepIndex, logs: [...cur.logs, log]);
    _emit();
  }

  @override
  Future<void> setStep(String uid, String skillId, int currentStepIndex) async {
    setStepCalls++;
    final cur = saved[skillId] ?? (currentStepIndex: 0, logs: <SkillLog>[]);
    saved[skillId] = (currentStepIndex: currentStepIndex, logs: cur.logs);
    _emit();
  }
}

/// In-memory [UserProgramRepository] for tests — records saves and emits live.
class FakeUserProgramRepository implements UserProgramRepository {
  final List<Program> saved = [];
  final StreamController<List<Program>> _controller =
      StreamController<List<Program>>.broadcast();

  void dispose() => _controller.close();

  @override
  Future<void> saveProgram(String uid, Program program) async {
    saved
      ..removeWhere((p) => p.id == program.id)
      ..add(program);
    _controller.add([...saved]);
  }

  @override
  Stream<List<Program>> watch(String uid) async* {
    yield [...saved];
    yield* _controller.stream;
  }
}
