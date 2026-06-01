import 'dart:async';

import 'package:calistrack/features/auth/data/auth_repository.dart';
import 'package:calistrack/features/profile/data/user_repository.dart';
import 'package:calistrack/models/app_user.dart';

/// In-memory [AuthRepository] for tests. Emits an initial user (or null) and
/// records calls so behaviour can be asserted without Firebase.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? initialUser, this.initialDelay = Duration.zero})
      : _current = initialUser;

  AppUser? _current;

  /// Simulates the real async gap before Firebase restores the auth state.
  final Duration initialDelay;
  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();

  /// When set, the next sign-in/register/google call throws this.
  Object? errorToThrow;
  int signInCalls = 0;
  int registerCalls = 0;
  int googleCalls = 0;
  int signOutCalls = 0;

  void dispose() => _controller.close();

  void _set(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    if (initialDelay > Duration.zero) await Future<void>.delayed(initialDelay);
    yield _current;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _current;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    _set(AppUser(uid: 'uid_$email', email: email));
  }

  @override
  Future<void> registerWithEmail({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    registerCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    _set(AppUser(uid: 'uid_$email', email: email, displayName: displayName));
  }

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    _set(const AppUser(uid: 'uid_google', email: 'google@example.com'));
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _set(null);
  }
}

/// In-memory [UserRepository] for tests.
class FakeUserRepository implements UserRepository {
  final Map<String, AppUser> store = {};
  int ensureCalls = 0;

  @override
  Future<AppUser?> fetch(String uid) async => store[uid];

  @override
  Stream<AppUser?> watch(String uid) => Stream.value(store[uid]);

  @override
  Future<void> upsert(AppUser user) async => store[user.uid] = user;

  @override
  Future<AppUser> ensureProfile(AppUser authUser) async {
    ensureCalls++;
    return store.putIfAbsent(authUser.uid, () => authUser);
  }
}
