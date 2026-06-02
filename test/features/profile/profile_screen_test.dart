import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/features/profile/presentation/profile_screen.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

Future<FakeUserRepository> _pump(
  WidgetTester tester,
  FakeAuthRepository auth, {
  FakeUserRepository? users,
}) async {
  final u = users ?? FakeUserRepository();
  addTearDown(() {
    auth.dispose();
    u.dispose();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(u),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return u;
}

void main() {
  testWidgets('unverified user sees the verify card and can resend',
      (tester) async {
    await _pump(
      tester,
      FakeAuthRepository(
        initialUser:
            const AppUser(uid: 'u1', email: 'a@b.com', emailVerified: false),
      ),
    );

    expect(find.text('Verify your email'), findsOneWidget);

    await tester.tap(find.text('Resend verification email'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Verification email sent'), findsOneWidget);
  });

  testWidgets('a verified user sees no verify card', (tester) async {
    await _pump(
      tester,
      FakeAuthRepository(
        initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
      ),
    );

    expect(find.text('Verify your email'), findsNothing);
  });

  testWidgets('a guest sees the upgrade card, not the verify card',
      (tester) async {
    await _pump(
      tester,
      FakeAuthRepository(
        initialUser: const AppUser(uid: 'g', email: '', isAnonymous: true),
      ),
    );

    expect(find.text('You’re a guest'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Verify your email'), findsNothing);
  });

  testWidgets('shows the saved profile level + goals (not the auth default)',
      (tester) async {
    final users = FakeUserRepository()
      ..store['u1'] = const AppUser(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Athlete',
        level: ExperienceLevel.advanced,
        goals: ['Skill', 'Strength'],
      );
    await _pump(
      tester,
      FakeAuthRepository(
        initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
      ),
      users: users,
    );

    // The real (advanced) level, not the auth identity's default Beginner.
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Beginner'), findsNothing);
    expect(find.widgetWithText(Chip, 'Skill'), findsOneWidget);
  });

  testWidgets('edit profile saves the changes', (tester) async {
    final users = FakeUserRepository()
      ..store['u1'] = const AppUser(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Old Name',
      );
    await _pump(
      tester,
      FakeAuthRepository(
        initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
      ),
      users: users,
    );

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'New Name',
    );
    await tester.tap(find.text('Intermediate'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(users.updateDetailsCalls, 1);
    expect(users.store['u1']!.displayName, 'New Name');
    expect(users.store['u1']!.level, ExperienceLevel.intermediate);
    // Returned to Profile with the new name shown.
    expect(find.text('New Name'), findsOneWidget);
  });
}
