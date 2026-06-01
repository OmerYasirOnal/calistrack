import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/program.dart';
import '../../profile/application/profile_providers.dart';
import '../data/program_repository.dart';
import '../data/user_program_repository.dart';
import 'ai_generation_screen.dart';
import 'widgets/program_card.dart';

/// Browse preset + your own (AI/saved) programs. Tap one to set it active, or
/// generate a tailored one.
class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetProgramsProvider);
    final userPrograms =
        ref.watch(userProgramsProvider).valueOrNull ?? const [];
    final activeId =
        ref.watch(currentUserProfileProvider).valueOrNull?.activeProgramId;

    Widget card(Program program) => ProgramCard(
          program: program,
          isActive: program.id == activeId,
          onTap: () => context.push(Routes.programDetail(program.id)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      floatingActionButton: FloatingActionButton.extended(
        // root navigator → the form is a full-screen modal over the tab bar.
        onPressed: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const AiGenerationScreen()),
        ),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generate'),
      ),
      body: presets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ProgramsError(
          onRetry: () => ref.invalidate(presetProgramsProvider),
        ),
        data: (programs) {
          // A user program never shadows a preset of the same id (the active
          // resolver prefers presets), so drop dupes to avoid a double card.
          final presetIds = programs.map((p) => p.id).toSet();
          final userOnly =
              userPrograms.where((p) => !presetIds.contains(p.id)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.md,
              Spacing.md,
              Spacing.xl * 2, // room for the FAB
            ),
            children: [
              if (userOnly.isNotEmpty) ...[
                const _SectionLabel('Your programs'),
                for (final p in userOnly) ...[
                  card(p),
                  const SizedBox(height: Spacing.md),
                ],
                const SizedBox(height: Spacing.sm),
                const _SectionLabel('Presets'),
              ],
              for (var i = 0; i < programs.length; i++) ...[
                card(programs[i]),
                if (i < programs.length - 1) const SizedBox(height: Spacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
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
