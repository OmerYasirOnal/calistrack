import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/skill_progress.dart';
import '../../billing/application/entitlement.dart';
import '../../billing/presentation/paywall_screen.dart';
import '../application/skill_providers.dart';
import '../data/skill_repository.dart';

String _stepTarget(SkillStep s) {
  if (s.targetHoldSeconds != null) return '${s.targetHoldSeconds}s hold';
  if (s.targetReps != null) return '${s.targetReps} reps';
  return '';
}

class SkillDetailScreen extends ConsumerWidget {
  const SkillDetailScreen({required this.skillId, super.key});

  final String skillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(userSkillsProvider);

    ref.listen(skillControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Could not update the skill.')),
          );
      }
    });

    return skills.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("Couldn't load this skill.")),
      ),
      data: (list) {
        final skill = list.firstWhereOrNull((s) => s.id == skillId);
        if (skill == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Skill not found.')),
          );
        }
        return _SkillDetail(skill: skill);
      },
    );
  }
}

class _SkillDetail extends ConsumerWidget {
  const _SkillDetail({required this.skill});

  final SkillProgress skill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = skill.currentStep;
    final controller = ref.read(skillControllerProvider.notifier);
    // Defence-in-depth: an advanced tree is Pro even if reached via a deep link.
    final locked = !skill.free && !ref.watch(entitlementProvider).isPro;

    return Scaffold(
      appBar: AppBar(title: Text(skill.name)),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          if (skill.description.isNotEmpty)
            Text(
              skill.description,
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: Spacing.lg),
          // Step ladder.
          for (var i = 0; i < skill.steps.length; i++)
            _StepTile(
              step: skill.steps[i],
              state: i < skill.currentStepIndex
                  ? _StepState.done
                  : i == skill.currentStepIndex
                      ? _StepState.current
                      : _StepState.locked,
            ),
          const SizedBox(height: Spacing.lg),
          if (locked)
            Card(
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_outline, color: scheme.primary),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Text(
                            'This skill-tree is a Pro feature',
                            style: text.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PaywallScreen(
                            reason: 'Full skill-trees are a Pro feature.',
                          ),
                        ),
                      ),
                      child: const Text('Unlock with Pro'),
                    ),
                  ],
                ),
              ),
            )
          else if (current != null) ...[
            _StepLogger(
              key: ValueKey(current.id),
              step: current,
              onLog: (log) => controller.logAttempt(skill.id, log),
            ),
            const SizedBox(height: Spacing.sm),
            FilledButton.icon(
              onPressed: () => controller.setStep(
                skill.id,
                (skill.currentStepIndex + 1).clamp(0, skill.steps.length),
              ),
              icon: const Icon(Icons.arrow_upward),
              label: const Text('Mark step complete'),
            ),
          ] else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, color: scheme.primary),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        'Skill complete — every step cleared!',
                        style: text.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!locked && skill.currentStepIndex > 0) ...[
            const SizedBox(height: Spacing.sm),
            TextButton(
              onPressed: () => controller.setStep(
                skill.id,
                (skill.currentStepIndex - 1).clamp(0, skill.steps.length),
              ),
              child: const Text('Step back'),
            ),
          ],
        ],
      ),
    );
  }
}

enum _StepState { done, current, locked }

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.state});

  final SkillStep step;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (state) {
      _StepState.done => (Icons.check_circle, scheme.primary),
      _StepState.current => (Icons.radio_button_checked, scheme.primary),
      _StepState.locked => (Icons.lock_outline, scheme.onSurfaceVariant),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        step.name,
        style: TextStyle(
          fontWeight:
              state == _StepState.current ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      subtitle: step.description.isEmpty ? null : Text(step.description),
      trailing: Text(_stepTarget(step)),
    );
  }
}

/// Per-step logging input — keyed by step id so it resets when the step
/// advances. Logs reps or hold-seconds depending on the step's target.
class _StepLogger extends StatefulWidget {
  const _StepLogger({required this.step, required this.onLog, super.key});

  final SkillStep step;
  final ValueChanged<SkillLog> onLog;

  @override
  State<_StepLogger> createState() => _StepLoggerState();
}

class _StepLoggerState extends State<_StepLogger> {
  late final bool _isHold = widget.step.targetHoldSeconds != null;
  late int _value =
      widget.step.targetHoldSeconds ?? widget.step.targetReps ?? 1;

  void _log() {
    widget.onLog(
      SkillLog(
        date: DateTime.now(),
        stepId: widget.step.id,
        holdSeconds: _isHold ? _value : null,
        reps: _isHold ? null : _value,
      ),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Attempt logged.')));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final increment = _isHold ? 5 : 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Log an attempt', style: text.titleSmall),
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => _value = (_value - increment).clamp(1, 9999),
                  ),
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Decrease ${_isHold ? 'seconds' : 'reps'}',
                ),
                Text(
                  _isHold ? '$_value s' : '$_value reps',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => _value = (_value + increment).clamp(1, 9999),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Increase ${_isHold ? 'seconds' : 'reps'}',
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            FilledButton(
              onPressed: _log,
              child: const Text('Log attempt'),
            ),
          ],
        ),
      ),
    );
  }
}
