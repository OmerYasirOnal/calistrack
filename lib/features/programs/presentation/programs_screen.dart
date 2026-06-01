import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/application/profile_providers.dart';
import '../data/program_repository.dart';
import 'widgets/program_card.dart';

/// Browse the preset programs. Tap one to see its days and set it active.
class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetProgramsProvider);
    final activeId =
        ref.watch(currentUserProfileProvider).valueOrNull?.activeProgramId;

    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      body: presets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ProgramsError(
          onRetry: () => ref.invalidate(presetProgramsProvider),
        ),
        data: (programs) => ListView.separated(
          padding: const EdgeInsets.all(Spacing.md),
          itemCount: programs.length,
          separatorBuilder: (_, __) => const SizedBox(height: Spacing.md),
          itemBuilder: (context, i) {
            final program = programs[i];
            return ProgramCard(
              program: program,
              isActive: program.id == activeId,
              onTap: () => context.push(Routes.programDetail(program.id)),
            );
          },
        ),
      ),
    );
  }
}

class _ProgramsError extends StatelessWidget {
  const _ProgramsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: Spacing.md),
            Text(
              "Couldn't load programs.",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
