import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/notifications/application/notification_service.dart';
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
  FakeNotificationService? notifications,
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
        if (notifications != null)
          notificationServiceProvider.overrideWithValue(notifications),
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

  testWidgets(
      'enabling the daily reminder persists + schedules the default '
      'time', (tester) async {
    final users = FakeUserRepository()
      ..store['u1'] = const AppUser(uid: 'u1', email: 'a@b.com');
    final notifications = FakeNotificationService();
    await _pump(
      tester,
      FakeAuthRepository(
        initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
      ),
      users: users,
      notifications: notifications,
    );

    expect(find.text('Daily reminder'), findsOneWidget);
    // Off → no time row yet.
    expect(find.text('Reminder time'), findsNothing);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(users.setReminderCalls, 1);
    expect(users.store['u1']!.reminderEnabled, isTrue);
    expect(users.store['u1']!.reminderMinutes, defaultReminderMinutes);
    // The UI scheduled with the SAME values it persisted.
    expect(
      notifications.applied,
      [(enabled: true, minutes: defaultReminderMinutes)],
    );
    // The time row now shows the default 6:00 PM.
    expect(find.text('Reminder time'), findsOneWidget);
    expect(find.text('6:00 PM'), findsOneWidget);
  });

  testWidgets('disabling the reminder keeps the chosen time + cancels',
      (tester) async {
    final users = FakeUserRepository()
      ..store['u1'] = const AppUser(
        uid: 'u1',
        email: 'a@b.com',
        reminderEnabled: true,
        reminderMinutes: 8 * 60, // 08:00
      );
    final notifications = FakeNotificationService();
    await _pump(
      tester,
      FakeAuthRepository(
        initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
      ),
      users: users,
      notifications: notifications,
    );

    expect(find.text('8:00 AM'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(users.store['u1']!.reminderEnabled, isFalse);
    // Time preserved so re-enabling restores it.
    expect(users.store['u1']!.reminderMinutes, 8 * 60);
    expect(notifications.applied, [(enabled: false, minutes: 8 * 60)]);
    expect(find.text('Reminder time'), findsNothing);
  });

  testWidgets(
      'enabling with denied OS permission rolls the toggle back '
      'and tells the user', (tester) async {
    final users = FakeUserRepository()
      ..store['u1'] = const AppUser(uid: 'u1', email: 'a@b.com');
    // Permission denied → scheduling reports failure.
    final notifications = FakeNotificationService(scheduleResult: false);
    await _pump(
      tester,
      FakeAuthRepository(
        initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
      ),
      users: users,
      notifications: notifications,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // The toggle is honest: rolled back off, with an explanatory SnackBar.
    expect(users.store['u1']!.reminderEnabled, isFalse);
    expect(
      find.textContaining('Enable notifications in Settings'),
      findsOneWidget,
    );
    expect(find.text('Reminder time'), findsNothing);
    // Persisted twice: the optimistic enable, then the rollback.
    expect(users.setReminderCalls, 2);
  });

  test('a targeted merge (setActiveProgram) preserves the reminder fields', () {
    final users = FakeUserRepository()
      ..store['u1'] = const AppUser(
        uid: 'u1',
        email: 'a@b.com',
        reminderEnabled: true,
        reminderMinutes: 9 * 60,
      );
    addTearDown(users.dispose);

    users.setActiveProgram('u1', 'ppl');

    // setActiveProgram only writes activeProgramId; the reminder (and every
    // other field) must survive the merge.
    final after = users.store['u1']!;
    expect(after.activeProgramId, 'ppl');
    expect(after.reminderEnabled, isTrue);
    expect(after.reminderMinutes, 9 * 60);
  });

  test('setReminder with a null minutes clears the stored time (merge null)',
      () async {
    final users = FakeUserRepository()
      ..store['u1'] = const AppUser(
        uid: 'u1',
        email: 'a@b.com',
        reminderEnabled: true,
        reminderMinutes: 9 * 60,
      );
    addTearDown(users.dispose);

    await users.setReminder('u1', enabled: false, minutes: null);

    // An explicit null override clears the field — the contract the real
    // Firestore merge relies on (writes reminderMinutes: null).
    expect(users.store['u1']!.reminderEnabled, isFalse);
    expect(users.store['u1']!.reminderMinutes, isNull);
  });
}
