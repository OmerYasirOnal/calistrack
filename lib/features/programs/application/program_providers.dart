import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/program.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/data/user_repository.dart';
import '../data/program_repository.dart';

/// The user's active program, resolved from the presets, or null if none set.
/// Awaits the profile (rather than reading a still-loading snapshot) so the UI
/// never flashes "no program" before the profile arrives.
/// (M5 will also resolve AI/custom programs from `users/{uid}/programs`.)
final activeProgramProvider = FutureProvider<Program?>((ref) async {
  final profile = await ref.watch(currentUserProfileProvider.future);
  final id = profile?.activeProgramId;
  if (id == null) return null;
  final presets = await ref.watch(presetProgramsProvider.future);
  return presets.firstWhereOrNull((p) => p.id == id);
});

/// Drives the "set as active program" action and exposes its async state for
/// button loading / error UI.
///
/// (Resolving the active pointer into a full [Program] lands in T13, where the
/// Today screen actually needs it.)
class ActiveProgramController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> setActive(String programId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final identity = ref.read(authStateProvider).valueOrNull;
      if (identity == null) {
        throw StateError('Cannot set an active program while signed out.');
      }
      await ref
          .read(userRepositoryProvider)
          .setActiveProgram(identity.uid, programId);
    });
  }
}

final activeProgramControllerProvider =
    AutoDisposeAsyncNotifierProvider<ActiveProgramController, void>(
  ActiveProgramController.new,
);
