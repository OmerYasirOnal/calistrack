import 'package:calistrack/app.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/features/workout/data/training_defaults.dart';
import 'package:calistrack/features/workout/data/workout_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
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
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
        ],
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
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
          workoutRepositoryProvider.overrideWithValue(workouts),
          // disable rest timers so pumpAndSettle isn't blocked by a countdown
          trainingDefaultsProvider.overrideWith(
            (ref) => const TrainingDefaults(
              restSecondsByType: {},
              defaultRestSeconds: 0,
            ),
          ),
        ],
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Boots to Today with the active program's day picker.
    expect(find.text('Push'), findsOneWidget);

    // Start the Push day → its movements appear, nothing logged yet.
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('0/11 sets'), findsOneWidget);

    // Log one set on the first movement.
    await tester.tap(find.byTooltip('Log set').first);
    await tester.pumpAndSettle();
    expect(find.text('1/11 sets'), findsOneWidget);

    // Finish → persisted + summary dialog.
    await tester.tap(find.text('Finish session'));
    await tester.pumpAndSettle();
    expect(find.text('Session complete'), findsOneWidget);
    expect(workouts.saved, hasLength(1));
  });
}
