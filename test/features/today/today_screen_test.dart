import 'package:calistrack/app.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/exercises/data/exercise_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/features/programs/data/program_repository.dart';
import 'package:calistrack/features/today/presentation/widgets/exercise_logger_card.dart';
import 'package:calistrack/features/workout/data/training_defaults.dart';
import 'package:calistrack/features/workout/data/workout_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:calistrack/models/exercise.dart';
import 'package:calistrack/models/program.dart';
import 'package:calistrack/models/workout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

// The real library + presets are loaded from assets ONCE and injected as
// synchronous overrides, so each full-app boot is deterministic (no asset load
// inside the pump loop, no flaky boot spinner).
late final List<Exercise> _library;
late final List<Program> _presets;

List<Override> _overrides({
  required AuthRepository auth,
  required UserRepository users,
  WorkoutRepository? workouts,
  int rest = 0,
}) =>
    [
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
      if (workouts != null)
        workoutRepositoryProvider.overrideWithValue(workouts),
      exerciseLibraryProvider.overrideWith((ref) => _library),
      presetProgramsProvider.overrideWith((ref) => _presets),
      trainingDefaultsProvider.overrideWith(
        (ref) => TrainingDefaults(
          restSecondsByType: const {},
          defaultRestSeconds: rest,
        ),
      ),
    ];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _library = await ExerciseRepository().all();
    _presets = await ProgramRepository().presets(_library);
  });

  testWidgets('no active program shows the empty state', (tester) async {
    const me = AppUser(uid: 'u1', email: 'a@b.com');
    final auth = FakeAuthRepository(initialUser: me);
    final users = FakeUserRepository()..store['u1'] = me;
    addTearDown(() {
      auth.dispose();
      users.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(auth: auth, users: users),
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active program yet'), findsOneWidget);
    expect(find.text('Choose a program'), findsOneWidget);
  });

  testWidgets('pick a day, log a set, and finish to a summary', (tester) async {
    const me =
        AppUser(uid: 'u1', email: 'a@b.com', activeProgramId: 'classic_ppl');
    final auth = FakeAuthRepository(initialUser: me);
    final users = FakeUserRepository()..store['u1'] = me;
    final workouts = FakeWorkoutRepository();
    addTearDown(() {
      auth.dispose();
      users.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(auth: auth, users: users, workouts: workouts),
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push'), findsOneWidget);

    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('0/11 sets'), findsOneWidget);

    await tester.tap(find.byTooltip('Log set').first);
    await tester.pumpAndSettle();
    expect(find.text('1/11 sets'), findsOneWidget);

    await tester.tap(find.text('Finish session'));
    await tester.pumpAndSettle();
    expect(find.text('Session complete'), findsOneWidget);
    expect(workouts.saved, hasLength(1));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  });

  testWidgets('seeds inputs + last-time reference from history',
      (tester) async {
    const me =
        AppUser(uid: 'u1', email: 'a@b.com', activeProgramId: 'classic_ppl');
    final auth = FakeAuthRepository(initialUser: me);
    final users = FakeUserRepository()..store['u1'] = me;
    final workouts = FakeWorkoutRepository()
      ..lastSets['push_up'] = const [LoggedSet(reps: 15, addedWeightKg: 5)];
    addTearDown(() {
      auth.dispose();
      users.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(auth: auth, users: users, workouts: workouts),
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();

    // Reps stepper seeded to 15 (not the target 12) and the reference shown.
    expect(find.text('Last time: 15·5kg'), findsOneWidget);
    expect(find.text('15'), findsWidgets);
  });

  testWidgets('rest timer appears after a set and can be skipped',
      (tester) async {
    const me =
        AppUser(uid: 'u1', email: 'a@b.com', activeProgramId: 'classic_ppl');
    final auth = FakeAuthRepository(initialUser: me);
    final users = FakeUserRepository()..store['u1'] = me;
    addTearDown(() {
      auth.dispose();
      users.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          auth: auth,
          users: users,
          workouts: FakeWorkoutRepository(),
          rest: 5,
        ),
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Log set').first);
    await tester.pump(); // show the rest timer (don't settle the countdown)
    expect(find.text('Skip'), findsOneWidget);
    expect(find.textContaining('Rest'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.text('Skip'), findsNothing); // back to the input row
  });

  testWidgets('logs a hold movement in seconds', (tester) async {
    const me =
        AppUser(uid: 'u1', email: 'a@b.com', activeProgramId: 'ppl_core');
    final auth = FakeAuthRepository(initialUser: me);
    final users = FakeUserRepository()..store['u1'] = me;
    addTearDown(() {
      auth.dispose();
      users.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          auth: auth,
          users: users,
          workouts: FakeWorkoutRepository(),
        ),
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Core'));
    await tester.pumpAndSettle();

    // Plank is a hold movement. Target its log button via its card (scroll-
    // proof — index-based finders shift as the lazy ListView builds/disposes).
    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('sec'), findsWidgets);
    final plankCard = find.ancestor(
      of: find.text('Plank'),
      matching: find.byType(ExerciseLoggerCard),
    );
    final plankLog =
        find.descendant(of: plankCard, matching: find.byTooltip('Log set'));
    await tester.ensureVisible(plankLog);
    await tester.pumpAndSettle();
    await tester.tap(plankLog);
    await tester.pumpAndSettle();
    expect(find.text('45s'), findsOneWidget);
  });
}
