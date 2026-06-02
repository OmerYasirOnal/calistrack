import 'package:calistrack/app.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  testWidgets('unauthenticated app gates to login and validates the form',
      (tester) async {
    final auth = FakeAuthRepository(); // null user → should land on /login
    final users = FakeUserRepository();
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

    // Gated to the login screen.
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

    // Submitting empty shows validation errors and never calls the repo.
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });

  testWidgets('forgot-password sends a reset email and closes the dialog',
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
        ],
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'forgot@b.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send link'));
    await tester.pumpAndSettle();

    expect(auth.resetCalls, 1);
    expect(auth.lastResetEmail, 'forgot@b.com');
    // Dialog closed; confirmation shown.
    expect(find.text('Reset password'), findsNothing);
    expect(find.textContaining('Reset link sent'), findsOneWidget);
  });

  testWidgets('forgot-password shows a retryable error, then succeeds',
      (tester) async {
    final auth = FakeAuthRepository()..errorToThrow = Exception('network');
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
        ],
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    final emailField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(emailField, 'x@y.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send link'));
    await tester.pumpAndSettle();

    // Error → dialog stays open, error shown.
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.textContaining('Could not send'), findsOneWidget);

    // Clearing the fault and retrying succeeds and closes the dialog.
    auth.errorToThrow = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Send link'));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsNothing);
    expect(find.textContaining('Reset link sent'), findsOneWidget);
  });

  testWidgets('forgot-password validates the email field (no silent no-op)',
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
        ],
        child: const CalisTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    // Empty field → tapping Send surfaces a validation error, doesn't call repo.
    final emailField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(emailField, '');
    await tester.tap(find.widgetWithText(FilledButton, 'Send link'));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
    expect(auth.resetCalls, 0);
  });
}
