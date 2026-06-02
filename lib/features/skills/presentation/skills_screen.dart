import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/skill_progress.dart';
import '../data/skill_repository.dart';

/// Browse skill progressions and your progress through each.
class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(userSkillsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Skills')),
      body: skills.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text("Couldn't load skills.")),
        data: (list) {
          // Show an intro until the user has advanced any skill — then it
          // disappears on its own (no manual dismiss to remember).
          final noProgress =
              list.isNotEmpty && list.every((s) => s.currentStepIndex == 0);
          return ListView(
            padding: const EdgeInsets.all(Spacing.md),
            children: [
              if (noProgress) ...[
                const _SkillsIntro(),
                const SizedBox(height: Spacing.md),
              ],
              for (final skill in list) ...[
                _SkillCard(
                  skill: skill,
                  onTap: () => context.push(Routes.skillDetail(skill.id)),
                ),
                const SizedBox(height: Spacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One-time intro shown on the Skills tab before any progress is recorded.
class _SkillsIntro extends StatelessWidget {
  const _SkillsIntro();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: scheme.primary),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                'Work toward these skills over time — open any one to log '
                'attempts and advance through its steps.',
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill, required this.onTap});

  final SkillProgress skill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = skill.currentStep;
    final done = current == null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      skill.name,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${(skill.completionRatio * 100).round()}%',
                    style: text.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                done ? 'Completed 🏆' : 'Next: ${current.name}',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.chip),
                child: LinearProgressIndicator(
                  value: skill.completionRatio,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
