import 'package:calistrack/app.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  testWidgets('shows a splash while auth resolves, never the protected shell',
      (tester) async {
    // Auth resolves to a signed-in user, but only after a delay — mimicking
    // the real Firebase cold-start gap that used to flash the Today shell.
    final auth = FakeAuthRepository(
      initialUser: const AppUser(uid: 'u1', email: 'a@b.com'),
      initialDelay: const Duration(milliseconds: 50),
    );
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

    // First frame while auth is still loading: splash, not Today.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No active program yet'), findsNothing);

    // After auth resolves, the gated router lands on Today (empty state here).
    await tester.pumpAndSettle();
    expect(find.text('No active program yet'), findsOneWidget);
  });
}
