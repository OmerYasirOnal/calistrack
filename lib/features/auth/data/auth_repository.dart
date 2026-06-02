import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../models/app_user.dart';

/// Auth abstraction so the app and tests depend on `AppUser`, never on the
/// concrete Firebase types.
abstract interface class AuthRepository {
  /// Emits the current user (or null) and every subsequent change.
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> registerWithEmail({
    required String email,
    required String password,
    String displayName,
  });

  Future<void> signInWithGoogle();

  /// Starts a guest (anonymous) session.
  Future<void> signInAnonymously();

  /// Upgrades the current anonymous session to a permanent email/password
  /// account, keeping the same uid so all the guest's data carries over.
  Future<void> linkEmailPassword({
    required String email,
    required String password,
    String displayName,
  });

  /// Sends a password-reset email (no-op visible to the user beyond the inbox).
  Future<void> sendPasswordResetEmail(String email);

  /// Sends a verification email to the currently signed-in user (no-op if none).
  Future<void> sendEmailVerification();

  /// Updates the auth identity's display name, keeping it in sync with the
  /// Firestore profile (no-op if signed out).
  Future<void> updateDisplayName(String displayName);

  Future<void> signOut();
}

/// Maps a Firebase [User] to the app's [AppUser] — the auth *identity* only
/// (uid/email/displayName/emailVerified/isAnonymous). It is NOT the source of
/// truth for level/goals/body-stats (those live in the Firestore profile, read
/// via `currentUserProfileProvider`); those fields keep their model defaults
/// here, so never read them off `authStateProvider`.
AppUser? mapFirebaseUser(User? user) => user == null
    ? null
    : AppUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
        emailVerified: user.emailVerified,
        isAnonymous: user.isAnonymous,
      );

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._googleSignIn);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map(mapFirebaseUser);

  @override
  AppUser? get currentUser => mapFirebaseUser(_auth.currentUser);

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> registerWithEmail({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (displayName.isNotEmpty) {
      await cred.user?.updateDisplayName(displayName);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return; // user cancelled the picker
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  @override
  Future<void> signInAnonymously() => _auth.signInAnonymously();

  @override
  Future<void> linkEmailPassword({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No guest session to upgrade.',
      );
    }
    final credential =
        EmailAuthProvider.credential(email: email, password: password);
    final result = await user.linkWithCredential(credential);
    if (displayName.isNotEmpty) {
      await result.user?.updateDisplayName(displayName);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName);
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(googleSignInProvider),
  ),
);

/// The single source of truth for "who is signed in". Drives router gating.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
