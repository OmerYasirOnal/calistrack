import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/program.dart';
import '../../profile/application/profile_providers.dart';
import '../application/program_providers.dart';
import '../data/program_repository.dart';
import 'program_format.dart';

/// A program's full breakdown — each day's movements and targets — with the
/// action to make it the user's active program.
class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({required this.programId, super.key});

  final String programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetProgramsProvider);

    ref.listen(activeProgramControllerProvider, (prev, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.hasError && !next.isLoading) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Could not update your program.')),
          );
      } else if ((prev?.isLoading ?? false) &&
          next.hasValue &&
          !next.isLoading) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Set as your active program.')),
          );
      }
    });

    return presets.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("Couldn't load this program.")),
      ),
      data: (programs) {
        final program = programs.firstWhereOrNull((p) => p.id == programId);
        if (program == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Program not found.')),
          );
        }
        return _ProgramDetail(program: program);
      },
    );
  }
}

class _ProgramDetail extends ConsumerWidget {
  const _ProgramDetail({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final activeId =
        ref.watch(currentUserProfileProvider).valueOrNull?.activeProgramId;
    final isActive = activeId == program.id;
    final saving = ref.watch(activeProgramControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(program.name)),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          if (program.description.isNotEmpty)
            Text(
              program.description,
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: Spacing.sm),
          Text(
            '${program.daysPerWeek} training days / week',
            style: text.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          for (final day in program.days) ...[
            _DaySection(day: day),
            const SizedBox(height: Spacing.lg),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: isActive
              ? const _ActiveFooter()
              : FilledButton(
                  onPressed: saving
                      ? null
                      : () => ref
                          .read(activeProgramControllerProvider.notifier)
                          .setActive(program.id),
                  child: saving
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Set as active program'),
                ),
        ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day});

  final ProgramDay day;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          day.label,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Spacing.sm),
        Card(
          child: Column(
            children: [
              for (final ex in day.exercises)
                ListTile(
                  dense: true,
                  title: Text(ex.name),
                  trailing: Text(
                    targetSummary(ex),
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveFooter extends StatelessWidget {
  const _ActiveFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, color: scheme.primary),
        const SizedBox(width: Spacing.sm),
        Text(
          'Your active program',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
