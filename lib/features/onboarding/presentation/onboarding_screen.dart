import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/app_user.dart';
import '../application/onboarding_answers.dart';
import '../application/onboarding_controller.dart';

/// First-run onboarding — a short, one-time flow that ends by stamping the
/// profile so the router lets the user into the app.
///
/// T26 ships two steps (Welcome → About You). T27 inserts the recommended-
/// program and first-session-primer steps before completion; the step list and
/// shared footer are built to extend without rework.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;

  static const _steps = <Widget>[
    _WelcomeStep(),
    _AboutYouStep(),
  ];

  bool get _isLast => _step == _steps.length - 1;

  void _next() => setState(() => _step++);
  void _back() => setState(() => _step--);

  void _finish() => ref.read(onboardingControllerProvider.notifier).complete();

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(onboardingControllerProvider).isLoading;

    // Keep the captured answers alive for the whole flow. Stepping Back unmounts
    // the About You step (the only other watcher), which would otherwise let the
    // AutoDispose provider reset and silently discard the user's selections.
    ref.watch(onboardingAnswersProvider);

    ref.listen(onboardingControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text("Couldn't finish setup. Please try again."),
            ),
          );
      }
    });

    final primaryLabel = _isLast
        ? 'Finish setup'
        : _step == 0
            ? 'Get started'
            : 'Continue';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(step: _step, total: _steps.length),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _steps[_step],
                ),
              ),
            ),
            _Footer(
              primaryLabel: primaryLabel,
              submitting: submitting,
              onBack: _step == 0 ? null : _back,
              onPrimary: submitting ? null : (_isLast ? _finish : _next),
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
                onPressed: submitting ? null : onBack,
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
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onChanged: (raw) =>
          onChanged(raw.trim().isEmpty ? null : double.tryParse(raw)),
    );
  }

  static String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
