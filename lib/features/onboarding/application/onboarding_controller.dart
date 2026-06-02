import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../profile/data/user_repository.dart';

/// Drives the one-time first-run onboarding. For now it exposes a single
/// [complete] action that stamps `onboardingCompletedAt` on the profile; the
/// router then redirects the user out of `/onboarding` automatically.
///
/// T26/T27 extend this with the captured answers (level/goals/days/equipment)
/// and the recommended-program step.
class OnboardingController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Marks onboarding finished for the signed-in user. Surfaces errors via
  /// [state] (an [AsyncError]) so the UI can show a retry instead of silently
  /// trapping the user on the onboarding screen.
  Future<void> complete() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) {
        throw StateError(
          'Cannot complete onboarding without a signed-in user.',
        );
      }
      await ref.read(userRepositoryProvider).completeOnboarding(
            uid,
            DateTime.now(),
          );
    });
  }
}

final onboardingControllerProvider =
    AutoDisposeAsyncNotifierProvider<OnboardingController, void>(
  OnboardingController.new,
);
