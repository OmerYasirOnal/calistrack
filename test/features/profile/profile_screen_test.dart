import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/presentation/profile_screen.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

Future<void> _pump(WidgetTester tester, FakeAuthRepository auth) async {
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
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
        // emailVerified defaults true.
        initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
      ),
    );

    expect(find.text('Verify your email'), findsNothing);
  });
}
