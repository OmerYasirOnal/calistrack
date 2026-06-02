import 'package:calistrack/features/auth/application/auth_controller.dart';
import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

ProviderContainer _container(
  FakeAuthRepository auth,
  FakeUserRepository users,
) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
    ],
  );
  // Keep the auto-dispose controller alive for the duration of the test.
  final sub = container.listen(authControllerProvider, (_, __) {});
  addTearDown(sub.close);
  addTearDown(container.dispose);
  addTearDown(auth.dispose);
  return container;
}

void main() {
  test('signInWithEmail signs in and bootstraps the profile', () async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final container = _container(auth, users);

    await container
        .read(authControllerProvider.notifier)
        .signInWithEmail('a@b.com', 'secret123');

    final state = container.read(authControllerProvider);
    expect(state.hasError, isFalse);
    expect(auth.signInCalls, 1);
    expect(auth.currentUser?.email, 'a@b.com');
    expect(users.ensureCalls, 1, reason: 'profile doc must be created');
    expect(users.store.containsKey('uid_a@b.com'), isTrue);
  });

  test('register creates the profile with the display name', () async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final container = _container(auth, users);

    await container
        .read(authControllerProvider.notifier)
        .registerWithEmail('new@b.com', 'secret123', displayName: 'Athlete');

    expect(auth.registerCalls, 1);
    expect(users.store['uid_new@b.com']?.displayName, 'Athlete');
    // A verification email is sent on sign-up.
    expect(auth.verifyCalls, 1);
  });

  test('a failed sign-in surfaces as an error state and skips bootstrap',
      () async {
    final auth = FakeAuthRepository()..errorToThrow = Exception('nope');
    final users = FakeUserRepository();
    final container = _container(auth, users);

    await container
        .read(authControllerProvider.notifier)
        .signInWithEmail('a@b.com', 'secret123');

    expect(container.read(authControllerProvider).hasError, isTrue);
    expect(users.ensureCalls, 0);
  });

  test('signOut clears the current user', () async {
    final auth = FakeAuthRepository(
      initialUser: const AppUser(uid: 'uid1', email: 'a@b.com'),
    );
    final users = FakeUserRepository();
    final container = _container(auth, users);

    await container.read(authControllerProvider.notifier).signOut();

    expect(auth.signOutCalls, 1);
    expect(auth.currentUser, isNull);
  });
}
