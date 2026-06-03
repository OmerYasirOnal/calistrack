import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/entitlement.dart';
import '../data/pricing.dart';

/// CalisTrack Pro paywall. Reachable from gated features (AI generation, full
/// skill-trees, advanced analytics) and from Profile. Real store billing is an
/// owner step (RevenueCat + store products); here, choosing a plan offers a
/// demo unlock so the $0 web/PWA build showcases the Pro experience.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({this.reason, super.key});

  /// Optional context line, e.g. "AI program generation is a Pro feature".
  final String? reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isPro = ref.watch(entitlementProvider).isPro;
    final pricing = ref.watch(pricingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CalisTrack Pro'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: isPro
          ? _ProActive(scheme: scheme, text: text)
          : pricing.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text("Couldn't load plans.")),
              data: (p) => _PaywallBody(pricing: p, reason: reason),
            ),
    );
  }
}

class _PaywallBody extends ConsumerWidget {
  const _PaywallBody({required this.pricing, this.reason});

  final Pricing pricing;
  final String? reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        Icon(Icons.workspace_premium, size: 56, color: scheme.primary),
        const SizedBox(height: Spacing.sm),
        Text(
          'Unlock your full potential',
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (reason != null) ...[
          const SizedBox(height: Spacing.xs),
          Text(
            reason!,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        for (final b in pricing.proBenefits)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: scheme.primary, size: 20),
                const SizedBox(width: Spacing.sm),
                Expanded(child: Text(b, style: text.bodyLarge)),
              ],
            ),
          ),
        const SizedBox(height: Spacing.md),
        for (final plan in pricing.plans)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: _PlanCard(
              plan: plan,
              onTap: () => _choosePlan(context, ref, plan),
            ),
          ),
        const SizedBox(height: Spacing.sm),
        TextButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No purchases to restore (demo).')),
          ),
          child: const Text('Restore purchases'),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'Subscriptions auto-renew until cancelled. Manage or cancel anytime in '
          'your store account. Privacy Policy · Terms of Use.',
          textAlign: TextAlign.center,
          style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _choosePlan(
    BuildContext context,
    WidgetRef ref,
    PricingPlan plan,
  ) async {
    final unlock = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${plan.title} — ${plan.priceUsd}'),
        content: const Text(
          'Real store billing is an owner setup step (store accounts + product '
          'IDs via RevenueCat). For this demo build you can unlock Pro instantly '
          'to explore the experience.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unlock (demo)'),
          ),
        ],
      ),
    );
    if (unlock ?? false) {
      ref.read(entitlementProvider.notifier).unlockProDemo();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're Pro 🎉 (demo)")),
        );
        await Navigator.of(context).maybePop();
      }
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onTap});

  final PricingPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = plan.highlighted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color:
              accent ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent ? scheme.primary : scheme.outlineVariant,
            width: accent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.title,
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (plan.badge != null) ...[
                        const SizedBox(width: Spacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            plan.badge!,
                            style: text.labelSmall?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (plan.subtitle.isNotEmpty)
                    Text(
                      plan.subtitle,
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.priceUsd,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  plan.period,
                  style:
                      text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProActive extends ConsumerWidget {
  const _ProActive({required this.scheme, required this.text});

  final ColorScheme scheme;
  final TextTheme text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium, size: 64, color: scheme.primary),
            const SizedBox(height: Spacing.md),
            Text(
              "You're Pro 🎉",
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'AI programs, full skill-trees, advanced analytics, and no ads are '
              'unlocked.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.lg),
            OutlinedButton(
              onPressed: () => ref.read(entitlementProvider.notifier).lock(),
              child: const Text('Switch back to Free (demo)'),
            ),
          ],
        ),
      ),
    );
  }
}
