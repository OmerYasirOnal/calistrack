import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/skill_progress.dart';
import '../../auth/data/auth_repository.dart';
import '../data/skill_repository.dart';

/// Drives skill actions (log an attempt, change the current step) and exposes
/// their async state for loading / error UI.
class SkillController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  String _requireUid() {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) throw StateError('Cannot update skills while signed out.');
    return uid;
  }

  Future<void> logAttempt(String skillId, SkillLog log) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(skillRepositoryProvider)
          .logAttempt(_requireUid(), skillId, log),
    );
  }

  Future<void> setStep(String skillId, int currentStepIndex) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(skillRepositoryProvider)
          .setStep(_requireUid(), skillId, currentStepIndex),
    );
  }
}

final skillControllerProvider =
    AutoDisposeAsyncNotifierProvider<SkillController, void>(
  SkillController.new,
);
