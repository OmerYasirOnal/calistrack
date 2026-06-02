import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/app_user.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../application/profile_providers.dart';
import 'edit_profile_screen.dart';

/// Profile & settings — identity, the saved details (level/goals/body stats),
/// account state (guest/verify), editing, and sign-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auth identity carries email / isAnonymous / emailVerified; the Firestore
    // profile doc carries the editable details (name / level / goals / stats).
    final identityAsync = ref.watch(authStateProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final signingOut = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (profile != null)
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EditProfileScreen(profile: profile),
                ),
              ),
            ),
        ],
      ),
      body: identityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load profile: $e')),
        data: (identity) {
          if (identity == null) {
            return const Center(child: Text('Not signed in.'));
          }
          // Prefer the profile doc for editable fields; fall back to the auth
          // identity until the doc resolves.
          final p = profile ?? identity;
          final name = p.displayName.isEmpty ? 'Athlete' : p.displayName;
          final text = Theme.of(context).textTheme;
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
                            Text(name, style: text.titleLarge),
                            if (identity.email.isNotEmpty)
                              Text(identity.email, style: text.bodyMedium),
                            const SizedBox(height: Spacing.xs),
                            Chip(label: Text(p.level.label)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (p.goals.isNotEmpty ||
                  p.heightCm != null ||
                  p.weightKg != null) ...[
                const SizedBox(height: Spacing.md),
                _DetailsCard(profile: p),
              ],
              if (identity.isAnonymous) ...[
                const SizedBox(height: Spacing.md),
                const _GuestUpgradeCard(),
              ] else if (!identity.emailVerified) ...[
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

/// Shows the user's goals + body stats (whatever they've set).
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final stats = <String>[
      if (profile.heightCm != null) '${_fmt(profile.heightCm!)} cm',
      if (profile.weightKg != null) '${_fmt(profile.weightKg!)} kg',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile.goals.isNotEmpty) ...[
              Text('Goals', style: text.titleSmall),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                children: [
                  for (final g in profile.goals) Chip(label: Text(g)),
                ],
              ),
            ],
            if (stats.isNotEmpty) ...[
              if (profile.goals.isNotEmpty) const SizedBox(height: Spacing.md),
              Text(
                stats.join(' · '),
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// Shown on Profile for a guest (anonymous) session — invites creating a real
/// account. Registering from here links in place, so guest data carries over.
class _GuestUpgradeCard extends StatelessWidget {
  const _GuestUpgradeCard();

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
                Icon(Icons.person_outline, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text('You’re a guest', style: text.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Create an account to back up your progress and sign in on other '
              'devices. Your current data carries over.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () => context.go(Routes.register),
                child: const Text('Create an account'),
              ),
            ),
          ],
        ),
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
