/// One step in a skill progression (e.g. "Tuck Front Lever").
class SkillStep {
  const SkillStep({
    required this.id,
    required this.name,
    this.description = '',
    this.targetHoldSeconds,
    this.targetReps,
  });

  final String id;
  final String name;
  final String description;
  final int? targetHoldSeconds;
  final int? targetReps;

  factory SkillStep.fromJson(Map<String, dynamic> json) => SkillStep(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        targetHoldSeconds: (json['targetHoldSeconds'] as num?)?.toInt(),
        targetReps: (json['targetReps'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        if (targetHoldSeconds != null) 'targetHoldSeconds': targetHoldSeconds,
        if (targetReps != null) 'targetReps': targetReps,
      };
}

/// A single logged attempt at a skill step.
class SkillLog {
  const SkillLog({
    required this.date,
    required this.stepId,
    this.holdSeconds,
    this.reps,
  });

  final DateTime date;
  final String stepId;
  final int? holdSeconds;
  final int? reps;

  factory SkillLog.fromJson(Map<String, dynamic> json) => SkillLog(
        date: DateTime.parse(json['date'] as String),
        stepId: json['stepId'] as String,
        holdSeconds: (json['holdSeconds'] as num?)?.toInt(),
        reps: (json['reps'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'stepId': stepId,
        if (holdSeconds != null) 'holdSeconds': holdSeconds,
        if (reps != null) 'reps': reps,
      };
}

/// A user's progression state for one skill (`users/{uid}/skills/{skillId}`).
class SkillProgress {
  const SkillProgress({
    required this.id,
    required this.name,
    required this.steps,
    this.currentStepIndex = 0,
    this.logs = const [],
  });

  final String id;
  final String name;
  final List<SkillStep> steps;
  final int currentStepIndex;
  final List<SkillLog> logs;

  SkillStep? get currentStep =>
      (currentStepIndex >= 0 && currentStepIndex < steps.length)
          ? steps[currentStepIndex]
          : null;

  double get completionRatio =>
      steps.isEmpty ? 0 : (currentStepIndex / steps.length).clamp(0, 1);

  factory SkillProgress.fromJson(Map<String, dynamic> json) => SkillProgress(
        id: json['id'] as String,
        name: json['name'] as String,
        steps: (json['steps'] as List<dynamic>? ?? [])
            .map((e) => SkillStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentStepIndex: (json['currentStepIndex'] as num?)?.toInt() ?? 0,
        logs: (json['logs'] as List<dynamic>? ?? [])
            .map((e) => SkillLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'steps': steps.map((e) => e.toJson()).toList(),
        'currentStepIndex': currentStepIndex,
        'logs': logs.map((e) => e.toJson()).toList(),
      };

  SkillProgress copyWith({
    int? currentStepIndex,
    List<SkillLog>? logs,
  }) =>
      SkillProgress(
        id: id,
        name: name,
        steps: steps,
        currentStepIndex: currentStepIndex ?? this.currentStepIndex,
        logs: logs ?? this.logs,
      );
}
