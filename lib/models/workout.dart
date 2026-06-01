/// A single logged set: reps and optional added weight (kg).
class LoggedSet {
  const LoggedSet({
    required this.reps,
    this.addedWeightKg = 0,
    this.holdSeconds,
    this.distanceMeters,
    this.durationSeconds,
  });

  final int reps;
  final double addedWeightKg;

  /// For isometric/hold exercises; null otherwise.
  final int? holdSeconds;

  /// For distance cardio (e.g. a run), in metres; null otherwise.
  final int? distanceMeters;

  /// For timed efforts/intervals, in seconds; null otherwise.
  final int? durationSeconds;

  /// Training volume contribution: reps × (bodyweight-relative + added weight).
  /// We approximate volume as reps × max(addedWeight, 1) so bodyweight sets
  /// still register. Cardio (distance/duration) is surfaced separately in the
  /// progress layer, not folded into strength volume.
  double get volume => reps * (addedWeightKg <= 0 ? 1 : addedWeightKg);

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
        reps: (json['reps'] as num?)?.toInt() ?? 0,
        addedWeightKg: (json['addedWeightKg'] as num?)?.toDouble() ?? 0,
        holdSeconds: (json['holdSeconds'] as num?)?.toInt(),
        distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'reps': reps,
        'addedWeightKg': addedWeightKg,
        if (holdSeconds != null) 'holdSeconds': holdSeconds,
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      };

  LoggedSet copyWith({
    int? reps,
    double? addedWeightKg,
    int? holdSeconds,
    int? distanceMeters,
    int? durationSeconds,
  }) =>
      LoggedSet(
        reps: reps ?? this.reps,
        addedWeightKg: addedWeightKg ?? this.addedWeightKg,
        holdSeconds: holdSeconds ?? this.holdSeconds,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );
}

/// All logged sets for one exercise within a workout.
class LoggedExercise {
  const LoggedExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
  });

  final String exerciseId;
  final String name;
  final List<LoggedSet> sets;

  int get totalReps => sets.fold(0, (sum, s) => sum + s.reps);
  double get totalVolume => sets.fold(0.0, (sum, s) => sum + s.volume);
  double get topWeight =>
      sets.fold(0.0, (max, s) => s.addedWeightKg > max ? s.addedWeightKg : max);

  factory LoggedExercise.fromJson(Map<String, dynamic> json) => LoggedExercise(
        exerciseId: json['exerciseId'] as String,
        name: json['name'] as String,
        sets: (json['sets'] as List<dynamic>? ?? [])
            .map((e) => LoggedSet.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'sets': sets.map((e) => e.toJson()).toList(),
      };

  LoggedExercise copyWith({List<LoggedSet>? sets}) => LoggedExercise(
        exerciseId: exerciseId,
        name: name,
        sets: sets ?? this.sets,
      );
}

/// A completed training session (`users/{uid}/workouts/{workoutId}`).
class Workout {
  const Workout({
    required this.id,
    required this.date,
    required this.exercises,
    this.programId,
    this.dayLabel = '',
    this.completed = false,
  });

  final String id;
  final DateTime date;
  final String? programId;
  final String dayLabel;
  final List<LoggedExercise> exercises;
  final bool completed;

  double get totalVolume =>
      exercises.fold(0.0, (sum, e) => sum + e.totalVolume);

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        programId: json['programId'] as String?,
        dayLabel: json['dayLabel'] as String? ?? '',
        exercises: (json['exercises'] as List<dynamic>? ?? [])
            .map((e) => LoggedExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        completed: json['completed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        if (programId != null) 'programId': programId,
        'dayLabel': dayLabel,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'completed': completed,
      };

  Workout copyWith({
    List<LoggedExercise>? exercises,
    bool? completed,
  }) =>
      Workout(
        id: id,
        date: date,
        programId: programId,
        dayLabel: dayLabel,
        exercises: exercises ?? this.exercises,
        completed: completed ?? this.completed,
      );
}
