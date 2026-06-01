import 'package:collection/collection.dart';

/// How an exercise is measured/performed.
enum ExerciseType {
  reps, // bodyweight reps (e.g. pull-ups)
  weightedReps, // reps with optional added weight (e.g. weighted dips)
  hold, // isometric hold measured in seconds (e.g. plank, lever holds)
  distance, // running / cardio measured in meters
  time; // timed effort measured in seconds (e.g. timed run)

  static ExerciseType fromName(String? name) =>
      ExerciseType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ExerciseType.reps,
      );
}

/// Primary muscle group a movement targets.
enum MuscleGroup {
  push,
  pull,
  legs,
  core,
  fullBody,
  cardio;

  static MuscleGroup fromName(String? name) => MuscleGroup.values.firstWhere(
        (e) => e.name == name,
        orElse: () => MuscleGroup.fullBody,
      );
}

/// A movement from the global exercise library (`exercises/{exerciseId}`).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.type,
    this.description = '',
  });

  final String id;
  final String name;
  final MuscleGroup muscleGroup;
  final ExerciseType type;
  final String description;

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String,
        muscleGroup: MuscleGroup.fromName(json['muscleGroup'] as String?),
        type: ExerciseType.fromName(json['type'] as String?),
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscleGroup': muscleGroup.name,
        'type': type.name,
        'description': description,
      };

  Exercise copyWith({
    String? id,
    String? name,
    MuscleGroup? muscleGroup,
    ExerciseType? type,
    String? description,
  }) =>
      Exercise(
        id: id ?? this.id,
        name: name ?? this.name,
        muscleGroup: muscleGroup ?? this.muscleGroup,
        type: type ?? this.type,
        description: description ?? this.description,
      );

  @override
  bool operator ==(Object other) =>
      other is Exercise &&
      other.id == id &&
      other.name == name &&
      other.muscleGroup == muscleGroup &&
      other.type == type &&
      other.description == description;

  @override
  int get hashCode => Object.hash(id, name, muscleGroup, type, description);
}

/// Equality helper for lists of exercises.
const exerciseListEquality = ListEquality<Exercise>();
