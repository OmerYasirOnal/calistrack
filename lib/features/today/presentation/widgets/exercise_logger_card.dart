import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/program.dart';
import '../../../../models/workout.dart';
import '../../../programs/presentation/program_format.dart';
import '../../../workout/application/workout_session.dart';

/// How a movement is logged, derived from which target field the preset sets.
enum LogMode { reps, hold, distance, time }

LogMode logModeFor(ProgramExercise e) {
  if (e.targetHoldSeconds != null) return LogMode.hold;
  if (e.targetDistanceMeters != null) return LogMode.distance;
  if (e.targetDurationSeconds != null) return LogMode.time;
  return LogMode.reps;
}

/// One movement's logging surface: target, last-time reference, the sets logged
/// this session, the input steppers + log action, and a post-set rest timer.
class ExerciseLoggerCard extends ConsumerStatefulWidget {
  const ExerciseLoggerCard({
    required this.exercise,
    required this.restSeconds,
    super.key,
  });

  final ProgramExercise exercise;
  final int restSeconds;

  @override
  ConsumerState<ExerciseLoggerCard> createState() => _ExerciseLoggerCardState();
}

class _ExerciseLoggerCardState extends ConsumerState<ExerciseLoggerCard> {
  late final LogMode _mode = logModeFor(widget.exercise);
  late int _reps = widget.exercise.targetReps ?? 10;
  double _weight = 0;
  late int _seconds = widget.exercise.targetHoldSeconds ??
      widget.exercise.targetDurationSeconds ??
      30;
  late int _meters = widget.exercise.targetDistanceMeters ?? 1000;

  bool _resting = false;

  void _log() {
    final set = switch (_mode) {
      LogMode.reps => LoggedSet(reps: _reps, addedWeightKg: _weight),
      LogMode.hold => LoggedSet(reps: 1, holdSeconds: _seconds),
      LogMode.distance => LoggedSet(reps: 1, distanceMeters: _meters),
      LogMode.time => LoggedSet(reps: 1, durationSeconds: _seconds),
    };
    ref
        .read(workoutSessionProvider.notifier)
        .logSet(widget.exercise.exerciseId, set);
    if (widget.restSeconds > 0) setState(() => _resting = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final logged = ref.watch(
      workoutSessionProvider.select(
        (s) => s?.setsFor(widget.exercise.exerciseId) ?? const <LoggedSet>[],
      ),
    );
    final lastSets = ref
            .watch(lastSetsForProvider(widget.exercise.exerciseId))
            .valueOrNull ??
        const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.exercise.name,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${logged.length}/${widget.exercise.targetSets}',
                  style: text.labelLarge?.copyWith(
                    color: logged.length >= widget.exercise.targetSets
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              'Target ${targetSummary(widget.exercise)}',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (lastSets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.xs),
                child: Text(
                  'Last time: ${_lastSummary(lastSets)}',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (logged.isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [
                  for (var i = 0; i < logged.length; i++)
                    _LoggedSetChip(
                      label: _setLabel(logged[i]),
                      onRemove: () => ref
                          .read(workoutSessionProvider.notifier)
                          .removeSet(widget.exercise.exerciseId, i),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Spacing.md),
            if (_resting)
              _RestTimer(
                seconds: widget.restSeconds,
                onDone: () => setState(() => _resting = false),
              )
            else
              _inputRow(scheme),
          ],
        ),
      ),
    );
  }

  Widget _inputRow(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(child: _primaryInput()),
        const SizedBox(width: Spacing.sm),
        IconButton.filled(
          onPressed: _log,
          icon: const Icon(Icons.add),
          tooltip: 'Log set',
        ),
      ],
    );
  }

  Widget _primaryInput() {
    return switch (_mode) {
      LogMode.reps => Row(
          children: [
            _Stepper(
              label: 'reps',
              value: '$_reps',
              onMinus: () => setState(() => _reps = (_reps - 1).clamp(0, 999)),
              onPlus: () => setState(() => _reps = _reps + 1),
            ),
            const SizedBox(width: Spacing.md),
            _Stepper(
              label: 'kg',
              value: _weight.toStringAsFixed(_weight % 1 == 0 ? 0 : 1),
              onMinus: () =>
                  setState(() => _weight = (_weight - 2.5).clamp(0, 999)),
              onPlus: () => setState(() => _weight = _weight + 2.5),
            ),
          ],
        ),
      LogMode.hold || LogMode.time => _Stepper(
          label: 'sec',
          value: '$_seconds',
          onMinus: () =>
              setState(() => _seconds = (_seconds - 5).clamp(0, 9999)),
          onPlus: () => setState(() => _seconds = _seconds + 5),
        ),
      LogMode.distance => _Stepper(
          label: 'metres',
          value: '$_meters',
          onMinus: () =>
              setState(() => _meters = (_meters - 100).clamp(0, 99999)),
          onPlus: () => setState(() => _meters = _meters + 100),
        ),
    };
  }

  String _setLabel(LoggedSet s) {
    if (s.holdSeconds != null) return '${s.holdSeconds}s';
    if (s.distanceMeters != null) {
      final m = s.distanceMeters!;
      return m >= 1000 ? '${(m / 1000).toStringAsFixed(1)}km' : '${m}m';
    }
    if (s.durationSeconds != null) return '${s.durationSeconds}s';
    if (s.addedWeightKg > 0) {
      return '${s.reps}·${s.addedWeightKg.toStringAsFixed(s.addedWeightKg % 1 == 0 ? 0 : 1)}kg';
    }
    return '${s.reps}';
  }

  String _lastSummary(List<LoggedSet> sets) => sets.map(_setLabel).join(' · ');
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onMinus,
          icon: const Icon(Icons.remove_circle_outline),
          visualDensity: VisualDensity.compact,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(label, style: text.labelSmall),
          ],
        ),
        IconButton(
          onPressed: onPlus,
          icon: const Icon(Icons.add_circle_outline),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _LoggedSetChip extends StatelessWidget {
  const _LoggedSetChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 16),
      backgroundColor: scheme.primary.withValues(alpha: 0.16),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// A simple countdown shown after a set is logged.
class _RestTimer extends StatefulWidget {
  const _RestTimer({required this.seconds, required this.onDone});

  final int seconds;
  final VoidCallback onDone;

  @override
  State<_RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<_RestTimer> {
  late int _remaining = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _timer?.cancel();
        widget.onDone();
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _label {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m > 0 ? '$m:' : ''}${s.toString().padLeft(m > 0 ? 2 : 1, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.timer_outlined, color: scheme.primary, size: 20),
        const SizedBox(width: Spacing.sm),
        Text('Rest ${_label}s', style: Theme.of(context).textTheme.titleSmall),
        const Spacer(),
        TextButton(onPressed: widget.onDone, child: const Text('Skip')),
      ],
    );
  }
}
