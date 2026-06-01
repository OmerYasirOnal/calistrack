import 'dart:convert';

import 'package:calistrack/features/skills/data/skill_repository.dart';
import 'package:calistrack/models/skill_progress.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('skill presets (skills.json)', () {
    late List<SkillProgress> skills;

    setUpAll(() async {
      final raw = await rootBundle.loadString('assets/data/skills.json');
      skills = (json.decode(raw) as List)
          .map((s) => SkillProgress.fromJson(s as Map<String, dynamic>))
          .toList();
    });

    test('parses the expected skill trees with descriptions', () {
      expect(skills, hasLength(5));
      expect(
        skills.map((s) => s.id),
        containsAll([
          'muscle_up',
          'front_lever',
          'planche',
          'handstand',
          'pistol_squat',
        ]),
      );
      expect(skills.every((s) => s.description.isNotEmpty), isTrue);
    });

    test('every step is well-formed with exactly one target', () {
      for (final skill in skills) {
        expect(skill.steps, isNotEmpty, reason: '${skill.id} has no steps');
        final ids = skill.steps.map((s) => s.id).toList();
        expect(
          ids.toSet(),
          hasLength(ids.length),
          reason: '${skill.id} has duplicate step ids',
        );
        for (final step in skill.steps) {
          expect(step.id.isNotEmpty && step.name.isNotEmpty, isTrue);
          final hasReps = step.targetReps != null;
          final hasHold = step.targetHoldSeconds != null;
          expect(
            hasReps ^ hasHold,
            isTrue,
            reason: '${skill.id}/${step.id} must have exactly one target',
          );
          final target = step.targetReps ?? step.targetHoldSeconds!;
          expect(target, greaterThan(0), reason: '${skill.id}/${step.id}');
        }
      }
    });

    test('completed skill (index == steps.length) → ratio 1, no current step',
        () {
      const skill = SkillProgress(
        id: 'x',
        name: 'X',
        steps: [SkillStep(id: 'a', name: 'A'), SkillStep(id: 'b', name: 'B')],
        currentStepIndex: 2,
      );
      expect(skill.completionRatio, 1.0);
      expect(skill.currentStep, isNull);
    });

    test('presets start at step 0 with no logs', () {
      expect(
        skills.every((s) => s.currentStepIndex == 0 && s.logs.isEmpty),
        isTrue,
      );
    });
  });

  group('mergeSkills', () {
    test('overlays saved step + logs, leaves unsaved skills untouched', () {
      const stepA1 = SkillStep(id: 's1', name: 'S1');
      const stepA2 = SkillStep(id: 's2', name: 'S2');
      const presets = [
        SkillProgress(id: 'a', name: 'A', steps: [stepA1, stepA2]),
        SkillProgress(id: 'b', name: 'B', steps: [stepA1]),
      ];
      final log = SkillLog(
        date: DateTime.utc(2026, 6, 1),
        stepId: 's1',
        holdSeconds: 12,
      );
      final saved = <String, SavedSkill>{
        'a': (currentStepIndex: 1, logs: [log]),
      };

      final merged = mergeSkills(presets, saved);
      final a = merged.firstWhere((s) => s.id == 'a');
      expect(a.currentStepIndex, 1);
      expect(a.logs.single.holdSeconds, 12);
      expect(a.steps, hasLength(2)); // steps preserved from the preset tree

      final b = merged.firstWhere((s) => s.id == 'b');
      expect(b.currentStepIndex, 0);
      expect(b.logs, isEmpty);
    });
  });
}
