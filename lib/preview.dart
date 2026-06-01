// Preview entrypoint — runs the app with in-memory repositories so the
// authenticated UI (Today / logging / Programs) can be exercised without a
// configured Firebase backend.
//
//   flutter run -t lib/preview.dart -d chrome
//   flutter build web -t lib/preview.dart
//
// Production uses lib/main.dart; nothing here ships in the real app.

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/profile/data/user_repository.dart';
import 'features/programs/application/program_providers.dart';
import 'features/workout/application/workout_session.dart';
import 'features/workout/data/workout_repository.dart';
import 'models/app_user.dart';
import 'models/workout.dart';

const _demoUser = AppUser(
  uid: 'preview',
  email: 'demo@calistrack.app',
  displayName: 'Demo',
  activeProgramId: 'classic_ppl',
);

LoggedExercise _pushUp(int a, int b, int c) => LoggedExercise(
      exerciseId: 'push_up',
      name: 'Push-up',
      sets: [LoggedSet(reps: a), LoggedSet(reps: b), LoggedSet(reps: c)],
    );

LoggedExercise _dip(int reps, double kg) => LoggedExercise(
      exerciseId: 'dip',
      name: 'Dip',
      sets: [
        LoggedSet(reps: reps, addedWeightKg: kg),
        LoggedSet(reps: reps - 1, addedWeightKg: kg),
      ],
    );

Workout _seedPush(
  String id,
  DateTime date,
  LoggedExercise pushUp,
  LoggedExercise dip,
) =>
    Workout(
      id: id,
      date: date,
      programId: 'classic_ppl',
      dayLabel: 'Push',
      completed: true,
      exercises: [pushUp, dip],
    );

// A few prior Push sessions so the "last time" reference + progress charts both
// have real data in the preview.
final _seedHistory = <Workout>[
  _seedPush('seed_1', DateTime(2026, 5, 24), _pushUp(10, 9, 8), _dip(6, 5)),
  _seedPush('seed_2', DateTime(2026, 5, 27), _pushUp(11, 10, 9), _dip(7, 7.5)),
  _seedPush('seed_3', DateTime(2026, 5, 30), _pushUp(12, 11, 10), _dip(8, 10)),
];

class _PreviewAuth implements AuthRepository {
  @override
  Stream<AppUser?> authStateChanges() => Stream.value(_demoUser);

  @override
  AppUser? get currentUser => _demoUser;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> registerWithEmail({
    required String email,
    required String password,
    String displayName = '',
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}

class _PreviewUsers implements UserRepository {
  final Map<String, AppUser> _store = {'preview': _demoUser};

  @override
  Future<AppUser?> fetch(String uid) async => _store[uid];

  @override
  Stream<AppUser?> watch(String uid) => Stream.value(_store[uid]);

  @override
  Future<void> upsert(AppUser user) async => _store[user.uid] = user;

  @override
  Future<AppUser> ensureProfile(AppUser authUser) async =>
      _store.putIfAbsent(authUser.uid, () => authUser);

  @override
  Future<void> setActiveProgram(String uid, String? programId) async {
    final base = _store[uid] ?? _demoUser;
    _store[uid] = base.copyWith(activeProgramId: programId);
  }
}

class _PreviewWorkouts implements WorkoutRepository {
  final List<Workout> _saved = [..._seedHistory];

  @override
  Future<void> save(String uid, Workout workout) async => _saved.add(workout);

  @override
  Future<List<Workout>> recent(String uid, {int limit = 20}) async {
    final sorted = [..._saved]..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<LoggedSet>> lastSetsFor(String uid, String exerciseId) async {
    for (final w in await recent(uid)) {
      final logged =
          w.exercises.firstWhereOrNull((e) => e.exerciseId == exerciseId);
      if (logged != null && logged.sets.isNotEmpty) return logged.sets;
    }
    return const [];
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_PreviewAuth()),
      userRepositoryProvider.overrideWithValue(_PreviewUsers()),
      workoutRepositoryProvider.overrideWithValue(_PreviewWorkouts()),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CalisTrackApp(),
    ),
  );
  _bootstrapSession(container);
}

/// Opens the app straight into a partially-logged Push session so the preview
/// shows the full logging UX (header progress, last-time refs, logged sets).
Future<void> _bootstrapSession(ProviderContainer container) async {
  final program = await container.read(activeProgramProvider.future);
  final push = program?.days.firstWhereOrNull((d) => d.label == 'Push');
  if (program == null || push == null) return;
  final controller = container.read(workoutSessionProvider.notifier)
    ..startDay(program, push);
  controller.logSet('push_up', const LoggedSet(reps: 12));
  controller.logSet('push_up', const LoggedSet(reps: 11));
}
