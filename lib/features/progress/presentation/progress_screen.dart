import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/exercise.dart';
import '../../ads/application/ad_service.dart';
import '../../exercises/data/exercise_repository.dart';
import '../data/progress_repository.dart';

/// The metric charted for an exercise, picked by how it's measured.
({String label, double Function(ExerciseDataPoint) value}) _metricFor(
  ExerciseType type,
) =>
    switch (type) {
      ExerciseType.reps || ExerciseType.weightedReps => (
          label: 'Volume',
          value: (p) => p.totalVolume
        ),
      ExerciseType.hold => (
          label: 'Best hold (s)',
          value: (p) => p.bestHoldSeconds.toDouble()
        ),
      ExerciseType.distance => (
          label: 'Distance (m)',
          value: (p) => p.totalDistanceMeters.toDouble()
        ),
      ExerciseType.time => (
          label: 'Duration (s)',
          value: (p) => p.totalDurationSeconds.toDouble()
        ),
    };

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: const _ProgressBody(),
    );
  }
}

class _ProgressBody extends ConsumerStatefulWidget {
  const _ProgressBody();

  @override
  ConsumerState<_ProgressBody> createState() => _ProgressBodyState();
}

class _ProgressBodyState extends ConsumerState<_ProgressBody> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(overallStatsProvider);
    final exercises = ref.watch(exercisesWithHistoryProvider);
    final library = ref.watch(exerciseLibraryProvider).valueOrNull ?? const [];

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        stats.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (s) => _StatsCard(stats: s),
        ),
        const SizedBox(height: Spacing.lg),
        exercises.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Center(child: Text("Couldn't load progress.")),
          data: (ids) => ids.isEmpty
              ? const _EmptyProgress()
              : _ExerciseChart(
                  ids: ids,
                  library: library,
                  // guard against a selection that's no longer in the list
                  selectedId:
                      ids.contains(_selectedId) ? _selectedId! : ids.first,
                  onSelect: (id) => setState(() => _selectedId = id),
                ),
        ),
        const SizedBox(height: Spacing.lg),
        // Banner ad (a no-op SizedBox on web/desktop/tests; mobile-only).
        Center(child: ref.watch(adServiceProvider).banner()),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final OverallStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: _Stat(
                value: '${stats.currentStreakDays}',
                label: 'day streak',
              ),
            ),
            Expanded(
              child: _Stat(
                value: '${stats.thisWeekWorkouts}',
                label: 'this week',
              ),
            ),
            Expanded(
              child: _Stat(value: '${stats.totalWorkouts}', label: 'workouts'),
            ),
            Expanded(
              child: _Stat(
                value: stats.totalVolume.toStringAsFixed(0),
                label: 'volume',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: text.headlineSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, style: text.labelSmall),
      ],
    );
  }
}

class _EmptyProgress extends StatelessWidget {
  const _EmptyProgress();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xl),
      child: Column(
        children: [
          Icon(Icons.show_chart, size: 56, color: scheme.primary),
          const SizedBox(height: Spacing.md),
          Text(
            'Log a few workouts and your progress charts will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.lg),
          FilledButton.icon(
            // .go (not .push): Today and Progress are separate shell branches,
            // so this switches tabs while keeping each branch's own stack.
            onPressed: () => context.go(Routes.today),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Log your first workout'),
          ),
        ],
      ),
    );
  }
}

class _ExerciseChart extends ConsumerWidget {
  const _ExerciseChart({
    required this.ids,
    required this.library,
    required this.selectedId,
    required this.onSelect,
  });

  final List<String> ids;
  final List<Exercise> library;
  final String selectedId;
  final ValueChanged<String> onSelect;

  String _nameOf(String id) =>
      library.firstWhereOrNull((e) => e.id == id)?.name ?? id;

  ExerciseType _typeOf(String id) =>
      library.firstWhereOrNull((e) => e.id == id)?.type ?? ExerciseType.reps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final history = ref.watch(exerciseHistoryProvider(selectedId));
    final metric = _metricFor(_typeOf(selectedId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ids.length,
            separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(_nameOf(ids[i])),
              selected: ids[i] == selectedId,
              onSelected: (_) => onSelect(ids[i]),
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        Text(
          metric.label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: Spacing.sm),
        history.when(
          loading: () => const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox(
            height: 220,
            child: Center(child: Text("Couldn't load history.")),
          ),
          data: (points) => points.length < 2
              ? SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      'Log this movement again to chart your trend.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                )
              : SizedBox(
                  height: 220,
                  child: _LineChart(
                    points: points,
                    value: metric.value,
                    color: scheme.primary,
                  ),
                ),
        ),
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.points,
    required this.value,
    required this.color,
  });

  final List<ExerciseDataPoint> points;
  final double Function(ExerciseDataPoint) value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), value(points[i])),
    ];

    return LineChart(
      LineChartData(
        minY: 0, // anchor at zero — avoids a collapsed axis when values match
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
