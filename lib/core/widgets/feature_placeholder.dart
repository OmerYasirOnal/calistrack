import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared scaffold for foundation-stage screens. Each feature milestone
/// replaces the body of its screen with the real implementation; this keeps
/// the five-tab shell coherent and navigable in the meantime.
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    required this.title,
    required this.icon,
    required this.message,
    this.milestone,
    super.key,
  });

  final String title;
  final IconData icon;
  final String message;
  final String? milestone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: scheme.primary),
              const SizedBox(height: Spacing.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (milestone != null) ...[
                const SizedBox(height: Spacing.sm),
                Text(
                  milestone!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
