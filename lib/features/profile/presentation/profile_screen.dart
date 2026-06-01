import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

/// Profile & settings. Built out in M2 (T8/T9): account, body metrics,
/// experience level, goals, sign-out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Profile',
      icon: Icons.person,
      message: 'Your profile, goals, and settings will appear here.',
      milestone: 'M2 · Auth & Profile',
    );
  }
}
