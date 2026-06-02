import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';

/// Profile & settings. M2 delivers identity + sign-out; body metrics, level,
/// and goals editing arrive with the profile-editing work later.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final signingOut = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load profile: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not signed in.'));
          }
          final name = user.displayName.isEmpty ? 'Athlete' : user.displayName;
          return ListView(
            padding: const EdgeInsets.all(Spacing.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              user.email,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: Spacing.xs),
                            Chip(label: Text(user.level.label)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!user.emailVerified) ...[
                const SizedBox(height: Spacing.md),
                const _VerifyEmailCard(),
              ],
              const SizedBox(height: Spacing.lg),
              OutlinedButton.icon(
                onPressed: signingOut
                    ? null
                    : () => ref.read(authControllerProvider.notifier).signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shown on Profile while the account's email is unverified — lets the user
/// resend the verification link. Manages its own send state.
class _VerifyEmailCard extends ConsumerStatefulWidget {
  const _VerifyEmailCard();

  @override
  ConsumerState<_VerifyEmailCard> createState() => _VerifyEmailCardState();
}

class _VerifyEmailCardState extends ConsumerState<_VerifyEmailCard> {
  bool _sending = false;

  Future<void> _resend() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Verification email sent.')),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not send the email.')),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mark_email_unread_outlined, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text('Verify your email', style: text.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'We sent a verification link to your inbox. Didn’t get it?',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _sending ? null : _resend,
                child: _sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Resend verification email'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
