import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';

/// Selectable onboarding options. These mirror the AI-generation form so the
/// answers captured here can feed program generation in T27. Kept as data (not
/// scattered string literals) per the no-magic-values rule.
const onboardingGoalOptions = ['Strength', 'Muscle', 'Skill', 'Endurance'];
const onboardingEquipmentOptions = ['Bar', 'Rings', 'Parallettes', 'None'];

/// Min/max for the days-per-week control.
const onboardingMinDays = 1;
const onboardingMaxDays = 7;

/// The answers captured during onboarding's "About You" step. [level], [goals],
/// [heightCm] and [weightKg] persist to the user profile; [daysPerWeek] and
/// [equipment] additionally feed the recommended-program step (T27).
class OnboardingAnswers {
  const OnboardingAnswers({
    this.level = ExperienceLevel.beginner,
    this.goals = const {},
    this.daysPerWeek = 3,
    this.equipment = const {},
    this.heightCm,
    this.weightKg,
  });

  final ExperienceLevel level;
  final Set<String> goals;
  final int daysPerWeek;
  final Set<String> equipment;
  final double? heightCm;
  final double? weightKg;

  OnboardingAnswers copyWith({
    ExperienceLevel? level,
    Set<String>? goals,
    int? daysPerWeek,
    Set<String>? equipment,
    double? heightCm,
    double? weightKg,
  }) =>
      OnboardingAnswers(
        level: level ?? this.level,
        goals: goals ?? this.goals,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        equipment: equipment ?? this.equipment,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
      );
}

/// Holds the in-progress onboarding answers as the user moves through the flow.
/// Auto-disposed: a fresh start each time onboarding is entered.
class OnboardingAnswersController
    extends AutoDisposeNotifier<OnboardingAnswers> {
  @override
  OnboardingAnswers build() => const OnboardingAnswers();

  void setLevel(ExperienceLevel level) => state = state.copyWith(level: level);

  void setDays(int days) => state = state.copyWith(
        daysPerWeek: days.clamp(onboardingMinDays, onboardingMaxDays),
      );

  void toggleGoal(String goal) {
    final next = {...state.goals};
    next.contains(goal) ? next.remove(goal) : next.add(goal);
    state = state.copyWith(goals: next);
  }

  void toggleEquipment(String item) {
    final next = {...state.equipment};
    next.contains(item) ? next.remove(item) : next.add(item);
    state = state.copyWith(equipment: next);
  }

  // Reconstructed (not copyWith) so passing null actually *clears* the stat —
  // copyWith's `?? this` can't represent "set back to null" when the user
  // empties the field.
  void setHeightCm(double? cm) => state = OnboardingAnswers(
        level: state.level,
        goals: state.goals,
        daysPerWeek: state.daysPerWeek,
        equipment: state.equipment,
        heightCm: cm,
        weightKg: state.weightKg,
      );

  void setWeightKg(double? kg) => state = OnboardingAnswers(
        level: state.level,
        goals: state.goals,
        daysPerWeek: state.daysPerWeek,
        equipment: state.equipment,
        heightCm: state.heightCm,
        weightKg: kg,
      );
}

final onboardingAnswersProvider =
    AutoDisposeNotifierProvider<OnboardingAnswersController, OnboardingAnswers>(
  OnboardingAnswersController.new,
);
