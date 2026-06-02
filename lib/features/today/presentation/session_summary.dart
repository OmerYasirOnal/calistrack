import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/workout.dart';

/// Celebratory summary shown after a session is finished + saved.
Future<void> showSessionSummary(BuildContext context, Workout workout) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SummaryDialog(workout: workout),
  );
}

class _SummaryDialog extends StatelessWidget {
  const _SummaryDialog({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sets = workout.exercises.fold(0, (s, e) => s + e.sets.length);
    final reps = workout.exercises.fold(0, (s, e) => s + e.totalReps);

    return AlertDialog(
      icon: Icon(Icons.emoji_events, color: scheme.primary, size: 40),
      title: const Text('Session complete'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            workout.dayLabel.isEmpty ? 'Workout' : '${workout.dayLabel} day',
            style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.md),
          _StatRow(label: 'Movements', value: '${workout.exercises.length}'),
          _StatRow(label: 'Sets', value: '$sets'),
          _StatRow(label: 'Total reps', value: '$reps'),
          _StatRow(
            label: 'Volume',
            value: workout.totalVolume.toStringAsFixed(0),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'Your Progress charts and skill streaks just updated.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: text.bodyLarge),
          Text(
            value,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
