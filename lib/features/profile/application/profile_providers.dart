import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../auth/data/auth_repository.dart';
import '../data/user_repository.dart';

/// The signed-in user's Firestore profile document (the source of truth for
/// `activeProgramId` and other persisted fields), or null when signed out.
///
/// Distinct from [authStateProvider], which carries only the auth *identity*.
final currentUserProfileProvider = StreamProvider<AppUser?>((ref) {
  final identity = ref.watch(authStateProvider).valueOrNull;
  if (identity == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watch(identity.uid);
});
