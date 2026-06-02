import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/onboarding_controller.dart';

/// First-run welcome. Minimal vertical slice for T25: a branded value-prop
/// panel and a "Get started" button that completes onboarding (the router then
/// routes the user into the app). T26 turns this into the first page of a
/// multi-step flow (Welcome → About You → Program → Primer).
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(onboardingControllerProvider);

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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.fitness_center, size: 72, color: scheme.primary),
              const SizedBox(height: Spacing.lg),
              Text(
                'Welcome to CalisTrack',
                textAlign: TextAlign.center,
                style:
                    text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Track calisthenics workouts, build strength, '
                'and unlock skills — one session at a time.',
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              FilledButton(
                onPressed: state.isLoading
                    ? null
                    : () => ref
                        .read(onboardingControllerProvider.notifier)
                        .complete(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: state.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Get started'),
              ),
              const SizedBox(height: Spacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
