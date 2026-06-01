import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../profile/data/user_repository.dart';

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
