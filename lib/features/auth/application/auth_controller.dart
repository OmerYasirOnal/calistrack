import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/user_repository.dart';
import '../data/auth_repository.dart';

/// Drives auth *actions* (sign-in/up/out) and exposes their async state for
/// loading/error UI. The signed-in *identity* is read from [authStateProvider].
class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  UserRepository get _users => ref.read(userRepositoryProvider);

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _auth.signInWithEmail(email: email, password: password);
      await _bootstrapProfile();
    });
  }

  Future<void> registerWithEmail(
    String email,
    String password, {
    String displayName = '',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final current = _auth.currentUser;
      if (current != null && current.isAnonymous) {
        // Upgrade the guest in place — same uid, so their data carries over.
        await _auth.linkEmailPassword(
          email: email,
          password: password,
          displayName: displayName,
        );
      } else {
        await _auth.registerWithEmail(
          email: email,
          password: password,
          displayName: displayName,
        );
      }
      await _bootstrapProfile();
      // Best-effort: a failed verification email must not fail registration.
      try {
        await _auth.sendEmailVerification();
      } catch (_) {/* user can resend from Profile */}
    });
  }

  Future<void> signInAnonymously() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _auth.signInAnonymously();
      await _bootstrapProfile();
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _auth.signInWithGoogle();
      await _bootstrapProfile();
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_auth.signOut);
  }

  /// T9: ensure `users/{uid}` exists after a successful auth.
  Future<void> _bootstrapProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _users.ensureProfile(user);
    }
  }
}

final authControllerProvider =
    AutoDisposeAsyncNotifierProvider<AuthController, void>(AuthController.new);
