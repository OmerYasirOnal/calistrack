import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/program.dart';
import '../../ads/application/ad_service.dart';
import '../../programs/application/program_providers.dart';
import '../../workout/application/workout_session.dart';
import '../../workout/data/training_defaults.dart';
import '../../exercises/data/exercise_repository.dart';
import 'session_summary.dart';
import 'widgets/exercise_logger_card.dart';

/// Today's training: pick a day from the active program, log sets, finish.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProgram = ref.watch(activeProgramProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: activeProgram.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text("Couldn't load your program.")),
        data: (program) =>
            program == null ? const _NoProgram() : _ActiveDay(program: program),
      ),
    );
  }
}

class _NoProgram extends StatelessWidget {
  const _NoProgram();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 64, color: scheme.primary),
            const SizedBox(height: Spacing.lg),
            Text(
              'No active program yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Pick a program and we’ll line up your sessions here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: () => context.go(Routes.programs),
              child: const Text('Choose a program'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveDay extends ConsumerStatefulWidget {
  const _ActiveDay({required this.program});

  final Program program;

  @override
  ConsumerState<_ActiveDay> createState() => _ActiveDayState();
}

class _ActiveDayState extends ConsumerState<_ActiveDay> {
  bool _finishing = false;

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      final workout = await ref.read(workoutSessionProvider.notifier).finish();
      if (!mounted) return;
      if (workout != null) {
        await showSessionSummary(context, workout);
        // Count this session and maybe show an interstitial (capped; no-op on
        // web/desktop/tests). Never blocks the training flow.
        await ref.read(adServiceProvider).maybeShowInterstitial();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Could not save your session.')),
          );
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider);
    final defaults = ref.watch(trainingDefaultsProvider).valueOrNull;
    final library = ref.watch(exerciseLibraryProvider).valueOrNull ?? const [];
    final typeById = {for (final e in library) e.id: e.type};
    final trainingDays =
        widget.program.days.where((d) => !d.isRest).toList(growable: false);

    int restFor(String exerciseId) {
      if (defaults == null) return 0; // still loading → no rest prompt yet
      final type = typeById[exerciseId];
      return type == null
          ? defaults.defaultRestSeconds
          : defaults.restSecondsFor(type);
    }

    return Column(
      children: [
        _DayPicker(
          program: widget.program,
          days: trainingDays,
          selected: session?.day.label,
          onSelect: (day) => ref.read(workoutSessionProvider.notifier).startDay(
                widget.program,
                day,
              ),
        ),
        if (session == null)
          const Expanded(child: _PickDayHint())
        else ...[
          _SessionHeader(session: session),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                0,
                Spacing.md,
                Spacing.md,
              ),
              children: [
                for (final ex in session.day.exercises)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.md),
                    child: ExerciseLoggerCard(
                      exercise: ex,
                      restSeconds: restFor(ex.exerciseId),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: FilledButton.icon(
                onPressed: (_finishing || !session.hasAnySet) ? null : _finish,
                icon: _finishing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Finish session'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.program,
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final Program program;
  final List<ProgramDay> days;
  final String? selected;
  final ValueChanged<ProgramDay> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            program.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            children: [
              for (final day in days)
                ChoiceChip(
                  label: Text(day.label),
                  selected: selected == day.label,
                  onSelected: (_) => onSelect(day),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickDayHint extends StatelessWidget {
  const _PickDayHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: Spacing.md),
            Text(
              'Pick a day above to start training.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${session.loggedSetTotal}/${session.targetSetTotal} sets',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Volume ${session.volume.toStringAsFixed(0)}',
                    style: text.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.chip),
                child: LinearProgressIndicator(
                  value: session.completion,
                  minHeight: 8,
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
