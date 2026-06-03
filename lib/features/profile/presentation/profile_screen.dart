import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/app_user.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../billing/application/entitlement.dart';
import '../../billing/presentation/paywall_screen.dart';
import '../../notifications/application/notification_service.dart';
import '../application/profile_providers.dart';
import '../data/user_repository.dart';
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
              const SizedBox(height: Spacing.md),
              const _ProCard(),
              const SizedBox(height: Spacing.md),
              _ReminderCard(profile: p),
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

/// CalisTrack Pro upsell / status. Free users get a "Go Pro" CTA to the
/// paywall; Pro users see active status. The Pro state is driven by
/// [entitlementProvider] (the billing seam).
class _ProCard extends ConsumerWidget {
  const _ProCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isPro = ref.watch(entitlementProvider).isPro;
    return Card(
      color: isPro ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    isPro ? 'CalisTrack Pro — active' : 'CalisTrack Pro',
                    style: text.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              isPro
                  ? 'AI programs, full skill-trees, advanced analytics, and no ads.'
                  : 'Unlock AI programs, full skill-trees, advanced analytics, '
                      'and remove ads.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PaywallScreen(),
                  ),
                ),
                child: Text(isPro ? 'Manage' : 'Go Pro'),
              ),
            ),
          ],
        ),
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

/// Opt-in daily workout reminder: a switch + a time row, both driven by the
/// persisted profile (the source of truth). Toggling/changing the time persists
/// the preference and (re)schedules the device notification — a no-op on
/// web/test, real on mobile.
class _ReminderCard extends ConsumerStatefulWidget {
  const _ReminderCard({required this.profile});

  final AppUser profile;

  @override
  ConsumerState<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends ConsumerState<_ReminderCard> {
  bool _busy = false;

  Future<void> _persist({required bool enabled, required int? minutes}) async {
    final messenger = ScaffoldMessenger.of(context);
    final uid = widget.profile.uid;
    final users = ref.read(userRepositoryProvider);
    setState(() => _busy = true);
    try {
      // Persist the intent first (the profile doc is the source of truth that
      // renders the switch), then schedule on the device.
      await users.setReminder(uid, enabled: enabled, minutes: minutes);
      var scheduled = true;
      try {
        scheduled = await ref
            .read(notificationServiceProvider)
            .applyReminder(enabled: enabled, minutes: minutes);
      } catch (_) {
        // A thrown failure while enabling counts as "not scheduled".
        scheduled = !enabled;
      }
      if (enabled && !scheduled) {
        // The OS notification permission was denied — roll the toggle back so it
        // doesn't lie (showing "on" while nothing fires) and explain why.
        await users.setReminder(uid, enabled: false, minutes: minutes);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Enable notifications in Settings to get reminders.',
              ),
            ),
          );
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not update the reminder.')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(bool on) => _persist(
        enabled: on,
        // Keep the chosen time across off/on; default it on first enable.
        minutes: widget.profile.reminderMinutes ?? defaultReminderMinutes,
      );

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: reminderTimeOfDay(
        widget.profile.reminderMinutes ?? defaultReminderMinutes,
      ),
    );
    if (picked == null) return;
    await _persist(enabled: true, minutes: picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.profile.reminderEnabled;
    final minutes = widget.profile.reminderMinutes ?? defaultReminderMinutes;
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Daily reminder'),
            subtitle: const Text('A nudge to keep your streak going'),
            value: enabled,
            onChanged: _busy ? null : _toggle,
          ),
          if (enabled)
            ListTile(
              contentPadding: const EdgeInsets.only(
                left: 72,
                right: Spacing.md,
              ),
              title: const Text('Reminder time'),
              trailing: Text(
                reminderTimeOfDay(minutes).format(context),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: _busy ? null : _pickTime,
            ),
        ],
      ),
    );
  }
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
