import 'package:calistrack/models/app_user.dart';
import 'package:calistrack/models/exercise.dart';
import 'package:calistrack/models/program.dart';
import 'package:calistrack/models/skill_progress.dart';
import 'package:calistrack/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Exercise', () {
    test('round-trips through JSON', () {
      const ex = Exercise(
        id: 'pull_up',
        name: 'Pull-up',
        muscleGroup: MuscleGroup.pull,
        type: ExerciseType.weightedReps,
        description: 'Vertical pull.',
      );
      expect(Exercise.fromJson(ex.toJson()), ex);
    });

    test('falls back to safe defaults on unknown enum strings', () {
      final ex = Exercise.fromJson({
        'id': 'x',
        'name': 'X',
        'muscleGroup': 'not_a_group',
        'type': 'not_a_type',
      });
      expect(ex.muscleGroup, MuscleGroup.fullBody);
      expect(ex.type, ExerciseType.reps);
    });
  });

  group('Program', () {
    test('round-trips and computes daysPerWeek excluding rest', () {
      final program = Program(
        id: 'ppl',
        name: 'Push Pull Legs',
        description: 'Classic split',
        source: ProgramSource.preset,
        createdAt: DateTime.utc(2026, 6, 1),
        days: const [
          ProgramDay(
            label: 'Push',
            exercises: [
              ProgramExercise(
                exerciseId: 'dip',
                name: 'Dip',
                targetSets: 4,
                targetReps: 10,
              ),
            ],
          ),
          ProgramDay(label: 'Rest', exercises: []),
        ],
      );
      final decoded = Program.fromJson(program.toJson());
      expect(decoded.name, 'Push Pull Legs');
      expect(decoded.days.length, 2);
      expect(decoded.daysPerWeek, 1);
      expect(decoded.days.first.exercises.first.targetReps, 10);
      expect(decoded.source, ProgramSource.preset);
    });
  });

  group('Workout', () {
    test('round-trips and aggregates volume', () {
      final workout = Workout(
        id: 'w1',
        date: DateTime.utc(2026, 6, 1),
        programId: 'ppl',
        dayLabel: 'Push',
        completed: true,
        exercises: const [
          LoggedExercise(
            exerciseId: 'dip',
            name: 'Dip',
            sets: [
              LoggedSet(reps: 10, addedWeightKg: 20),
              LoggedSet(reps: 8, addedWeightKg: 20),
            ],
          ),
        ],
      );
      final decoded = Workout.fromJson(workout.toJson());
      expect(decoded.completed, true);
      expect(decoded.exercises.first.totalReps, 18);
      expect(decoded.exercises.first.topWeight, 20);
      expect(decoded.totalVolume, (10 * 20) + (8 * 20));
    });

    test('bodyweight set still contributes volume', () {
      const set = LoggedSet(reps: 12);
      expect(set.volume, 12);
    });
  });

  group('SkillProgress', () {
    test('round-trips and reports completion ratio', () {
      final skill = SkillProgress(
        id: 'front_lever',
        name: 'Front Lever',
        currentStepIndex: 2,
        steps: const [
          SkillStep(id: 'tuck', name: 'Tuck'),
          SkillStep(id: 'adv_tuck', name: 'Advanced Tuck'),
          SkillStep(id: 'straddle', name: 'Straddle'),
          SkillStep(id: 'full', name: 'Full'),
        ],
        logs: [
          SkillLog(
            date: DateTime.utc(2026, 6, 1),
            stepId: 'tuck',
            holdSeconds: 10,
          ),
        ],
      );
      final decoded = SkillProgress.fromJson(skill.toJson());
      expect(decoded.currentStep?.name, 'Straddle');
      expect(decoded.completionRatio, 0.5);
      expect(decoded.logs.single.holdSeconds, 10);
    });
  });

  group('AppUser', () {
    test('round-trips and omits null optionals', () {
      const user = AppUser(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Athlete',
        level: ExperienceLevel.intermediate,
        goals: ['muscle_up', 'front_lever'],
      );
      final json = user.toJson();
      expect(json.containsKey('heightCm'), false);
      final decoded = AppUser.fromJson(json);
      expect(decoded.level, ExperienceLevel.intermediate);
      expect(decoded.goals, ['muscle_up', 'front_lever']);
    });
  });
}
