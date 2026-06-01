import 'package:calistrack/app.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('a signed-in user boots to the Today tab with five destinations',
      (tester) async {
    final auth = FakeAuthRepository(
      initialUser: const AppUser(uid: 'u1', email: 'a@b.com', displayName: 'A'),
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
    await tester.pumpAndSettle();

    // Today is the initial tab (no active program yet → empty state).
    expect(find.text('No active program yet'), findsOneWidget);

    // All five destinations are present.
    for (final label in [
      'Today',
      'Programs',
      'Progress',
      'Skills',
      'Profile',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    // Tapping Programs navigates to the real program list (preset loaded).
    await tester.tap(find.text('Programs'));
    await tester.pumpAndSettle();
    expect(find.text('Classic PPL'), findsOneWidget);
  });
}
