import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/app_user.dart';
import '../../../models/program.dart';
import '../../programs/application/ai_program_service.dart';
import '../../programs/presentation/program_format.dart';
import '../../workout/application/workout_session.dart';
import '../application/onboarding_answers.dart';
import '../application/onboarding_controller.dart';

/// First-run onboarding — a short, one-time flow that ends by stamping the
/// profile (so the router lets the user in) on an active program, mid-session,
/// ready to log their first set.
///
/// Steps: Welcome → About You → Your program (recommended, set active) →
/// First session primer (starts the Day-1 session, then completes).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _total = 4;
  int _step = 0;
  Program? _chosen;
  bool _busy = false;

  void _next() => setState(() => _step++);
  void _back() => setState(() => _step--);

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Save the recommended program (makes it active) and advance to the primer.
  Future<void> _useProgram(Program program) async {
    setState(() => _busy = true);
    try {
      await ref.read(aiGenerationControllerProvider.notifier).save(program);
      if (!mounted) return;
      setState(() {
        _chosen = program;
        _busy = false;
        _step++;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack("Couldn't save the program. Please try again.");
    }
  }

  /// Escape hatch: finish onboarding without a recommended program. The empty
  /// Today guides the user to the Programs tab to pick one manually.
  void _skipToManual() =>
      ref.read(onboardingControllerProvider.notifier).complete();

  /// Start the first training day's session, then complete onboarding so the
  /// user lands on Today already in their first session. If completion fails,
  /// cancel the just-started session so we don't leave a live session behind a
  /// still-locked onboarding gate.
  Future<void> _startTraining() async {
    final program = _chosen;
    final firstDay = program?.days.firstWhereOrNull((d) => !d.isRest);
    final session = ref.read(workoutSessionProvider.notifier);
    if (program != null && firstDay != null) {
      session.startDay(program, firstDay);
    }
    // complete() uses AsyncValue.guard, so it resolves (never throws) — check
    // the resulting state for failure.
    await ref.read(onboardingControllerProvider.notifier).complete();
    if (!mounted) return;
    if (ref.read(onboardingControllerProvider).hasError) {
      session.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final completing = ref.watch(onboardingControllerProvider).isLoading;
    // Keep the captured answers + the in-progress generation alive for the whole
    // flow, so stepping Back never discards the user's selections or program.
    ref.watch(onboardingAnswersProvider);
    final gen = ref.watch(aiGenerationControllerProvider);

    ref.listen(onboardingControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        _snack("Couldn't finish setup. Please try again.");
      }
    });

    final busy = _busy || completing;

    final Widget stepWidget = switch (_step) {
      0 => const _WelcomeStep(),
      1 => const _AboutYouStep(),
      2 => _ProgramStep(onSkipToManual: busy ? null : _skipToManual),
      _ => _PrimerStep(program: _chosen),
    };

    final (String primaryLabel, VoidCallback? onPrimary) = switch (_step) {
      0 => ('Get started', _next),
      1 => ('Continue', _next),
      2 => (
          'Start this program',
          gen.valueOrNull == null
              ? null
              : () => _useProgram(gen.value!.program),
        ),
      _ => ('Start training', _startTraining),
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(step: _step, total: _total),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(key: ValueKey(_step), child: stepWidget),
              ),
            ),
            _Footer(
              primaryLabel: primaryLabel,
              submitting: busy,
              onBack: (_step == 0 || busy) ? null : _back,
              onPrimary: busy ? null : onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.lg,
        Spacing.lg,
        Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Step ${step + 1} of $total', style: text.labelMedium),
          const SizedBox(height: Spacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.chip),
            child: LinearProgressIndicator(value: (step + 1) / total),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.primaryLabel,
    required this.submitting,
    required this.onBack,
    required this.onPrimary,
  });

  final String primaryLabel;
  final bool submitting;
  final VoidCallback? onBack;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Row(
        children: [
          if (onBack != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: Spacing.md),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(primaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 72, color: scheme.primary),
          const SizedBox(height: Spacing.lg),
          Text(
            'Welcome to CalisTrack',
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Track calisthenics workouts, build strength, and unlock skills — '
            'one session at a time. A couple of quick questions and we’ll set '
            'you up with the right program.',
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AboutYouStep extends ConsumerWidget {
  const _AboutYouStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final answers = ref.watch(onboardingAnswersProvider);
    final controller = ref.read(onboardingAnswersProvider.notifier);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      children: [
        Text(
          'About you',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          'This tailors your starting program. You can change it later.',
          style: text.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.lg),
        Text('Experience', style: text.titleSmall),
        const SizedBox(height: Spacing.sm),
        SegmentedButton<ExperienceLevel>(
          segments: [
            for (final l in ExperienceLevel.values)
              ButtonSegment(value: l, label: Text(l.label)),
          ],
          selected: {answers.level},
          onSelectionChanged: (s) => controller.setLevel(s.first),
        ),
        const SizedBox(height: Spacing.lg),
        Text('Days per week', style: text.titleSmall),
        Row(
          children: [
            IconButton(
              onPressed: answers.daysPerWeek <= onboardingMinDays
                  ? null
                  : () => controller.setDays(answers.daysPerWeek - 1),
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Fewer days',
            ),
            Text('${answers.daysPerWeek}', style: text.titleLarge),
            IconButton(
              onPressed: answers.daysPerWeek >= onboardingMaxDays
                  ? null
                  : () => controller.setDays(answers.daysPerWeek + 1),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'More days',
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        Text('Goals', style: text.titleSmall),
        _Chips(
          options: onboardingGoalOptions,
          selected: answers.goals,
          onToggle: controller.toggleGoal,
        ),
        const SizedBox(height: Spacing.md),
        Text('Equipment', style: text.titleSmall),
        _Chips(
          options: onboardingEquipmentOptions,
          selected: answers.equipment,
          onToggle: controller.toggleEquipment,
        ),
        const SizedBox(height: Spacing.sm),
        _BodyStats(
          heightCm: answers.heightCm,
          weightKg: answers.weightKg,
          onHeight: controller.setHeightCm,
          onWeight: controller.setWeightKg,
        ),
        const SizedBox(height: Spacing.md),
      ],
    );
  }
}

/// Generates a recommended program from the answers (AI when reachable, local
/// fallback otherwise) and previews it. The footer's "Start this program" saves
/// + activates it; "Pick one myself" is the escape hatch.
class _ProgramStep extends ConsumerStatefulWidget {
  const _ProgramStep({required this.onSkipToManual});

  final VoidCallback? onSkipToManual;

  @override
  ConsumerState<_ProgramStep> createState() => _ProgramStepState();
}

class _ProgramStepState extends ConsumerState<_ProgramStep> {
  @override
  void initState() {
    super.initState();
    // Kick off generation once, after the first frame (can't read providers in
    // initState synchronously for a Notifier action).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gen = ref.read(aiGenerationControllerProvider);
      if (gen.valueOrNull != null || gen.isLoading) return;
      final a = ref.read(onboardingAnswersProvider);
      ref.read(aiGenerationControllerProvider.notifier).generate(
            GenerationRequest(
              level: a.level,
              daysPerWeek: a.daysPerWeek,
              goals: a.goals.toList(),
              equipment: a.equipment.toList(),
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(aiGenerationControllerProvider);

    if (state.isLoading || state.valueOrNull == null) {
      return Center(child: _Building(onSkip: widget.onSkipToManual));
    }
    if (state.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't build a program."),
              const SizedBox(height: Spacing.sm),
              TextButton(
                onPressed: widget.onSkipToManual,
                child: const Text('Pick one myself'),
              ),
            ],
          ),
        ),
      );
    }

    final result = state.value!;
    final program = result.program;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      children: [
        Text(
          'Your program',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Spacing.sm),
        if (result.usedFallback) ...[
          Card(
            color: scheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(Spacing.md),
              child: Text(
                'Built from a matching template (AI service not connected yet).',
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.name,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  '${program.daysPerWeek} days/week · '
                  '${program.days.where((d) => !d.isRest).length} sessions',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        for (final day in program.days.where((d) => !d.isRest)) ...[
          Text(
            day.label,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          for (final ex in day.exercises)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(ex.name),
              trailing: Text(targetSummary(ex)),
            ),
          const SizedBox(height: Spacing.sm),
        ],
        const SizedBox(height: Spacing.sm),
        Center(
          child: TextButton(
            onPressed: widget.onSkipToManual,
            child: const Text('Pick one myself'),
          ),
        ),
        const SizedBox(height: Spacing.md),
      ],
    );
  }
}

class _Building extends StatelessWidget {
  const _Building({required this.onSkip});

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: Spacing.md),
        Text(
          'Building your program…',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (onSkip != null) ...[
          const SizedBox(height: Spacing.md),
          TextButton(onPressed: onSkip, child: const Text('Pick one myself')),
        ],
      ],
    );
  }
}

/// Final step: a quick look at the first session + a legend, then "Start
/// training" drops the user into that session on the Today tab.
class _PrimerStep extends StatelessWidget {
  const _PrimerStep({required this.program});

  final Program? program;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final firstDay = program?.days.firstWhereOrNull((d) => !d.isRest);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      children: [
        Icon(Icons.rocket_launch_outlined, size: 56, color: scheme.primary),
        const SizedBox(height: Spacing.md),
        Text(
          "You're all set!",
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          firstDay == null
              ? 'Tap Start training to begin.'
              : 'First up: ${firstDay.label}. Tap a movement’s +/- to log each '
                  'set, then Finish session when you’re done.',
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Spacing.lg),
        if (firstDay != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstDay.label,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  for (final ex in firstDay.exercises)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(ex.name)),
                          Text(
                            targetSummary(ex),
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      children: [
        for (final o in options)
          FilterChip(
            label: Text(o),
            selected: selected.contains(o),
            onSelected: (_) => onToggle(o),
          ),
      ],
    );
  }
}

/// Optional height/weight, collapsed by default so it never blocks the flow.
class _BodyStats extends StatelessWidget {
  const _BodyStats({
    required this.heightCm,
    required this.weightKg,
    required this.onHeight,
    required this.onWeight,
  });

  final double? heightCm;
  final double? weightKg;
  final ValueChanged<double?> onHeight;
  final ValueChanged<double?> onWeight;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Drop the default ExpansionTile divider lines for a cleaner look.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: Spacing.sm),
        title: const Text('Add body stats (optional)'),
        children: [
          Row(
            children: [
              Expanded(
                child: _NumField(
                  label: 'Height (cm)',
                  value: heightCm,
                  onChanged: onHeight,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _NumField(
                  label: 'Weight (kg)',
                  value: weightKg,
                  onChanged: onWeight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value == null ? '' : _trimZero(value!),
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (raw) =>
          onChanged(raw.trim().isEmpty ? null : double.tryParse(raw)),
    );
  }

  static String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
