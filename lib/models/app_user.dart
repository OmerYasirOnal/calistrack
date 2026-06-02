enum ExperienceLevel {
  beginner,
  intermediate,
  advanced;

  static ExperienceLevel fromName(String? name) =>
      ExperienceLevel.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ExperienceLevel.beginner,
      );

  String get label => switch (this) {
        ExperienceLevel.beginner => 'Beginner',
        ExperienceLevel.intermediate => 'Intermediate',
        ExperienceLevel.advanced => 'Advanced',
      };
}

/// User profile document (`users/{uid}`).
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.heightCm,
    this.weightKg,
    this.level = ExperienceLevel.beginner,
    this.goals = const [],
    this.activeProgramId,
    this.onboardingCompletedAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final double? heightCm;
  final double? weightKg;
  final ExperienceLevel level;
  final List<String> goals;
  final String? activeProgramId;

  /// When the one-time first-run onboarding was finished. Null means the user
  /// has not completed onboarding yet — this is what the router's `/onboarding`
  /// gate keys off. Persisted as an ISO-8601 string, matching the date
  /// convention used elsewhere (see `Workout.date`), so the model stays free of
  /// any Firestore `Timestamp` dependency.
  final DateTime? onboardingCompletedAt;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: json['uid'] as String,
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        level: ExperienceLevel.fromName(json['level'] as String?),
        goals: (json['goals'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        activeProgramId: json['activeProgramId'] as String?,
        onboardingCompletedAt:
            DateTime.tryParse(json['onboardingCompletedAt'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        if (heightCm != null) 'heightCm': heightCm,
        if (weightKg != null) 'weightKg': weightKg,
        'level': level.name,
        'goals': goals,
        if (activeProgramId != null) 'activeProgramId': activeProgramId,
        if (onboardingCompletedAt != null)
          'onboardingCompletedAt': onboardingCompletedAt!.toIso8601String(),
      };

  AppUser copyWith({
    String? displayName,
    double? heightCm,
    double? weightKg,
    ExperienceLevel? level,
    List<String>? goals,
    String? activeProgramId,
    DateTime? onboardingCompletedAt,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        level: level ?? this.level,
        goals: goals ?? this.goals,
        activeProgramId: activeProgramId ?? this.activeProgramId,
        onboardingCompletedAt:
            onboardingCompletedAt ?? this.onboardingCompletedAt,
      );
}
