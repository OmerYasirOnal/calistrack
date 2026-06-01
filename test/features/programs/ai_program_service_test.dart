import 'package:calistrack/features/programs/application/ai_program_service.dart';
import 'package:calistrack/models/app_user.dart';
import 'package:calistrack/models/exercise.dart';
import 'package:calistrack/models/program.dart';
import 'package:flutter_test/flutter_test.dart';

const _library = [
  Exercise(
    id: 'push_up',
    name: 'Push-up',
    muscleGroup: MuscleGroup.push,
    type: ExerciseType.reps,
  ),
];

ProgramDay _day(String label) => ProgramDay(
      label: label,
      exercises: const [
        ProgramExercise(
          exerciseId: 'push_up',
          name: 'Push-up',
          targetSets: 3,
          targetReps: 10,
        ),
      ],
    );

final _presets = [
  Program(
    id: 'classic_ppl',
    name: 'Classic PPL',
    source: ProgramSource.preset,
    days: [_day('Push'), _day('Pull'), _day('Legs')],
  ),
  Program(
    id: 'foundations',
    name: 'Foundations',
    source: ProgramSource.preset,
    days: [_day('Full Body')],
  ),
];

void main() {
  group('fallbackProgram', () {
    test('picks the preset matching daysPerWeek, renamed by goal', () {
      const req = GenerationRequest(
        level: ExperienceLevel.intermediate,
        daysPerWeek: 3,
        goals: ['strength'],
      );
      final program = fallbackProgram(req, _presets);
      expect(program.daysPerWeek, 3); // Classic PPL's day structure
      expect(program.name, 'Your strength plan');
      expect(program.source, ProgramSource.custom);
    });

    test('falls back to Foundations when no preset matches days', () {
      const req = GenerationRequest(
        level: ExperienceLevel.beginner,
        daysPerWeek: 7,
      );
      final program = fallbackProgram(req, _presets);
      expect(program.days, hasLength(1)); // Foundations
      expect(program.name, 'Your custom plan');
    });
  });

  group('AiProgramService.generate', () {
    test('parses a function response, resolving names + dropping unknown ids',
        () async {
      final service = AiProgramService(
        caller: (_) async => {
          'name': 'AI Plan',
          'description': 'tailored',
          'days': [
            {
              'label': 'Push',
              'exercises': [
                {'exerciseId': 'push_up', 'targetSets': 4, 'targetReps': 8},
                {'exerciseId': 'ghost', 'targetSets': 3, 'targetReps': 5},
              ],
            },
          ],
        },
      );

      final result = await service.generate(
        const GenerationRequest(
          level: ExperienceLevel.advanced,
          daysPerWeek: 1,
        ),
        library: _library,
        presets: _presets,
      );

      expect(result.usedFallback, isFalse);
      expect(result.program.source, ProgramSource.ai);
      final exercises = result.program.days.single.exercises;
      expect(exercises, hasLength(1)); // 'ghost' dropped
      expect(exercises.single.name, 'Push-up'); // resolved from library
      expect(exercises.single.targetReps, 8);
    });

    test('parses the real platform shape (nested Map<Object?, Object?>)',
        () async {
      // cloud_functions decodes nested objects as Map<Object?, Object?>, NOT
      // Map<String, dynamic> — the parser must not cast to the latter.
      final service = AiProgramService(
        caller: (_) async => <String, dynamic>{
          'name': 'AI Plan',
          'days': <Object?>[
            <Object?, Object?>{
              'label': 'Push',
              'exercises': <Object?>[
                <Object?, Object?>{
                  'exerciseId': 'push_up',
                  'targetSets': 3,
                  'targetReps': 9,
                },
              ],
            },
          ],
        },
      );
      final result = await service.generate(
        const GenerationRequest(
          level: ExperienceLevel.beginner,
          daysPerWeek: 1,
        ),
        library: _library,
        presets: _presets,
      );
      expect(result.usedFallback, isFalse); // did NOT silently fall back
      expect(result.program.days.single.exercises.single.targetReps, 9);
    });

    test('falls back when the function throws', () async {
      final service =
          AiProgramService(caller: (_) async => throw Exception('x'));
      final result = await service.generate(
        const GenerationRequest(
          level: ExperienceLevel.beginner,
          daysPerWeek: 3,
        ),
        library: _library,
        presets: _presets,
      );
      expect(result.usedFallback, isTrue);
      expect(result.program.daysPerWeek, 3);
    });

    test('falls back when the response has no usable days', () async {
      final service = AiProgramService(
        caller: (_) async => {
          'name': 'Empty',
          'days': [
            {
              'label': 'X',
              'exercises': [
                {
                  'exerciseId': 'unknown_only',
                  'targetSets': 3,
                  'targetReps': 5,
                },
              ],
            },
          ],
        },
      );
      final result = await service.generate(
        const GenerationRequest(
          level: ExperienceLevel.beginner,
          daysPerWeek: 3,
        ),
        library: _library,
        presets: _presets,
      );
      expect(result.usedFallback, isTrue); // unknown-only day → no usable days
    });
  });
}
