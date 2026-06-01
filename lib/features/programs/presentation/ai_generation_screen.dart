import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/app_user.dart';
import '../../../models/program.dart';
import '../application/ai_program_service.dart';
import 'program_format.dart';

const _goalOptions = ['Strength', 'Muscle', 'Skill', 'Endurance'];
const _equipmentOptions = ['Bar', 'Rings', 'Parallettes', 'None'];

/// Form → generate (AI or fallback) → preview → save as the active program.
class AiGenerationScreen extends ConsumerStatefulWidget {
  const AiGenerationScreen({super.key});

  @override
  ConsumerState<AiGenerationScreen> createState() => _AiGenerationScreenState();
}

class _AiGenerationScreenState extends ConsumerState<AiGenerationScreen> {
  ExperienceLevel _level = ExperienceLevel.beginner;
  int _days = 3;
  final Set<String> _goals = {};
  final Set<String> _equipment = {};
  bool _saving = false;

  void _generate() {
    ref.read(aiGenerationControllerProvider.notifier).generate(
          GenerationRequest(
            level: _level,
            daysPerWeek: _days,
            goals: _goals.toList(),
            equipment: _equipment.toList(),
          ),
        );
  }

  Future<void> _save(Program program) async {
    setState(() => _saving = true);
    try {
      await ref.read(aiGenerationControllerProvider.notifier).save(program);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Saved as your active program.')),
        );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Could not save the program.')),
          );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(aiGenerationControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Generation failed. Try again.')),
          );
      }
    });

    final state = ref.watch(aiGenerationControllerProvider);
    final result = state.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Generate a program')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : result == null
              ? _form()
              : _preview(result),
    );
  }

  Widget _form() {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        Text('Experience', style: text.titleSmall),
        const SizedBox(height: Spacing.sm),
        SegmentedButton<ExperienceLevel>(
          segments: [
            for (final l in ExperienceLevel.values)
              ButtonSegment(value: l, label: Text(l.label)),
          ],
          selected: {_level},
          onSelectionChanged: (s) => setState(() => _level = s.first),
        ),
        const SizedBox(height: Spacing.lg),
        Text('Days per week', style: text.titleSmall),
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _days = (_days - 1).clamp(1, 7)),
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Fewer days',
            ),
            Text('$_days', style: text.titleLarge),
            IconButton(
              onPressed: () => setState(() => _days = (_days + 1).clamp(1, 7)),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'More days',
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        Text('Goals', style: text.titleSmall),
        _chips(_goalOptions, _goals),
        const SizedBox(height: Spacing.md),
        Text('Equipment', style: text.titleSmall),
        _chips(_equipmentOptions, _equipment),
        const SizedBox(height: Spacing.xl),
        FilledButton.icon(
          onPressed: _generate,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generate'),
        ),
      ],
    );
  }

  Widget _chips(List<String> options, Set<String> selected) {
    return Wrap(
      spacing: Spacing.sm,
      children: [
        for (final o in options)
          FilterChip(
            label: Text(o),
            selected: selected.contains(o),
            onSelected: (on) => setState(
              () => on ? selected.add(o) : selected.remove(o),
            ),
          ),
      ],
    );
  }

  Widget _preview(GenerationResult result) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final program = result.program;

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        if (result.usedFallback)
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
        Text(
          program.name,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (program.description.isNotEmpty)
          Text(
            program.description,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        const SizedBox(height: Spacing.md),
        for (final day in program.days) ...[
          Text(
            day.label,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
        const SizedBox(height: Spacing.md),
        FilledButton.icon(
          onPressed: _saving ? null : () => _save(program),
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Save & set active'),
        ),
        const SizedBox(height: Spacing.sm),
        TextButton(
          onPressed: () =>
              ref.invalidate(aiGenerationControllerProvider), // back to form
          child: const Text('Start over'),
        ),
      ],
    );
  }
}
