import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/skill_progress.dart';
import '../../billing/application/entitlement.dart';
import '../../billing/presentation/paywall_screen.dart';
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
          final isPro = ref.watch(entitlementProvider).isPro;
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
                  key: ValueKey(skill.id),
                  skill: skill,
                  // Advanced trees are Pro; foundational ones (skill.free) are
                  // open. Locked cards route to the paywall, not the detail.
                  locked: !skill.free && !isPro,
                  onTap: () {
                    if (!skill.free && !isPro) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PaywallScreen(
                            reason: 'Full skill-trees are a Pro feature.',
                          ),
                        ),
                      );
                    } else {
                      context.push(Routes.skillDetail(skill.id));
                    }
                  },
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
  const _SkillCard({
    required this.skill,
    required this.onTap,
    this.locked = false,
    super.key,
  });

  final SkillProgress skill;
  final VoidCallback onTap;
  final bool locked;

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
                  if (locked)
                    _ProTag(scheme: scheme, text: text)
                  else
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
                locked
                    ? 'Unlock this skill-tree with Pro'
                    : done
                        ? 'Completed 🏆'
                        : 'Next: ${current.name}',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (!locked) ...[
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Small "PRO" lock tag shown on a gated skill card.
class _ProTag extends StatelessWidget {
  const _ProTag({required this.scheme, required this.text});

  final ColorScheme scheme;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 12, color: scheme.onPrimary),
          const SizedBox(width: 4),
          Text(
            'PRO',
            style: text.labelSmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
