/// A planned movement inside a program day (target sets/reps, not a log).
class ProgramExercise {
  const ProgramExercise({
    required this.exerciseId,
    required this.name,
    required this.targetSets,
    this.targetReps,
    this.targetHoldSeconds,
    this.targetDistanceMeters,
    this.targetDurationSeconds,
    this.notes = '',
  });

  final String exerciseId;
  final String name;
  final int targetSets;

  /// Target reps per set (null for hold/distance/time based movements).
  final int? targetReps;

  /// Target hold seconds per set (null for rep based movements).
  final int? targetHoldSeconds;

  /// Target distance in metres per set (cardio, e.g. a 5 km run).
  final int? targetDistanceMeters;

  /// Target duration in seconds per set (timed efforts/intervals).
  final int? targetDurationSeconds;
  final String notes;

  factory ProgramExercise.fromJson(Map<String, dynamic> json) =>
      ProgramExercise(
        exerciseId: json['exerciseId'] as String,
        name: json['name'] as String,
        targetSets: (json['targetSets'] as num?)?.toInt() ?? 3,
        targetReps: (json['targetReps'] as num?)?.toInt(),
        targetHoldSeconds: (json['targetHoldSeconds'] as num?)?.toInt(),
        targetDistanceMeters: (json['targetDistanceMeters'] as num?)?.toInt(),
        targetDurationSeconds: (json['targetDurationSeconds'] as num?)?.toInt(),
        notes: json['notes'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'targetSets': targetSets,
        if (targetReps != null) 'targetReps': targetReps,
        if (targetHoldSeconds != null) 'targetHoldSeconds': targetHoldSeconds,
        if (targetDistanceMeters != null)
          'targetDistanceMeters': targetDistanceMeters,
        if (targetDurationSeconds != null)
          'targetDurationSeconds': targetDurationSeconds,
        'notes': notes,
      };
}

/// One training day within a program.
class ProgramDay {
  const ProgramDay({
    required this.label,
    required this.exercises,
  });

  /// Human label, e.g. "Push", "Pull", "Rest".
  final String label;
  final List<ProgramExercise> exercises;

  bool get isRest => exercises.isEmpty;

  factory ProgramDay.fromJson(Map<String, dynamic> json) => ProgramDay(
        label: json['label'] as String,
        exercises: (json['exercises'] as List<dynamic>? ?? [])
            .map((e) => ProgramExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}

/// A full training program (`users/{uid}/programs/{programId}`).
class Program {
  const Program({
    required this.id,
    required this.name,
    required this.days,
    this.description = '',
    this.source = ProgramSource.preset,
    this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final List<ProgramDay> days;
  final ProgramSource source;
  final DateTime? createdAt;

  int get daysPerWeek => days.where((d) => !d.isRest).length;

  factory Program.fromJson(Map<String, dynamic> json) => Program(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        days: (json['days'] as List<dynamic>? ?? [])
            .map((e) => ProgramDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        source: ProgramSource.fromName(json['source'] as String?),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'days': days.map((e) => e.toJson()).toList(),
        'source': source.name,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  Program copyWith({
    String? id,
    String? name,
    String? description,
    List<ProgramDay>? days,
    ProgramSource? source,
    DateTime? createdAt,
  }) =>
      Program(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        days: days ?? this.days,
        source: source ?? this.source,
        createdAt: createdAt ?? this.createdAt,
      );
}

enum ProgramSource {
  preset,
  ai,
  custom;

  static ProgramSource fromName(String? name) =>
      ProgramSource.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ProgramSource.custom,
      );
}
