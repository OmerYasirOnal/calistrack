import 'package:calistrack/app.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/features/programs/data/program_repository.dart';
import 'package:calistrack/features/programs/data/user_program_repository.dart';
import 'package:calistrack/features/programs/presentation/program_detail_screen.dart';
import 'package:calistrack/features/programs/presentation/programs_screen.dart';
import 'package:calistrack/models/program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  testWidgets('lists presets, opens a detail, and sets it active',
      (tester) async {
    final me = onboardedUser();
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

    // The preset list renders.
    await tester.tap(find.text('Programs'));
    await tester.pumpAndSettle();
    expect(find.text('Classic PPL'), findsOneWidget);

    // Opening a program shows its movements + the set-active action.
    await tester.tap(find.text('Classic PPL'));
    await tester.pumpAndSettle();
    expect(find.text('Push-up'), findsOneWidget); // a Push-day movement
    expect(find.text('Set as active program'), findsOneWidget);

    // Setting it active persists to the profile and flips the footer.
    await tester.tap(find.text('Set as active program'));
    await tester.pumpAndSettle();
    expect(users.setActiveCalls, 1);
    expect(users.store['u1']!.activeProgramId, 'classic_ppl');
    expect(find.text('Your active program'), findsOneWidget);
  });

  testWidgets('detail shows "not found" for an unknown program id',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Resolve immediately (no real asset load) so the not-found branch is
        // isolated and deterministic regardless of test order.
        overrides: [
          presetProgramsProvider.overrideWith((ref) => <Program>[]),
        ],
        child: const MaterialApp(
          home: ProgramDetailScreen(programId: 'no_such_id'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Program not found.'), findsOneWidget);
  });

  testWidgets('programs list shows an error state with retry on load failure',
      (tester) async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    addTearDown(() {
      auth.dispose();
      users.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
          presetProgramsProvider.overrideWith(
            (ref) async => throw StateError('boom'),
          ),
        ],
        child: const MaterialApp(home: ProgramsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load programs."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows a "Your programs" section and dedupes preset-id clashes',
      (tester) async {
    final me = onboardedUser();
    final auth = FakeAuthRepository(initialUser: me);
    final users = FakeUserRepository()..store['u1'] = me;
    final userPrograms = FakeUserProgramRepository();
    addTearDown(() {
      auth.dispose();
      users.dispose();
      userPrograms.dispose();
    });
    const foundations = Program(
      id: 'foundations',
      name: 'Foundations',
      source: ProgramSource.preset,
      days: [
        ProgramDay(
          label: 'Full Body',
          exercises: [
            ProgramExercise(
              exerciseId: 'push_up',
              name: 'Push-up',
              targetSets: 3,
              targetReps: 8,
            ),
          ],
        ),
      ],
    );
    // One genuine user program + one that clashes with a preset id (must dedupe).
    await userPrograms.saveProgram(
      'u1',
      foundations.copyWith(id: 'gen_1', name: 'My Plan'),
    );
    await userPrograms.saveProgram('u1', foundations.copyWith(name: 'Dup'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
          userProgramRepositoryProvider.overrideWithValue(userPrograms),
          presetProgramsProvider.overrideWith((ref) => [foundations]),
        ],
        child: const MaterialApp(home: ProgramsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your programs'), findsOneWidget);
    expect(find.text('My Plan'), findsOneWidget); // genuine user program
    // The preset-id clash ('foundations') is deduped → exactly one Foundations.
    expect(find.text('Foundations'), findsOneWidget);
    expect(find.text('Dup'), findsNothing);
  });
}
