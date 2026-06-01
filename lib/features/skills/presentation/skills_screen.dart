import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

/// Skill progression. Built out in M4 (T17/T18): muscle-up, front lever, etc.
/// with step-by-step progression and hold-time/rep logging.
class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Skills',
      icon: Icons.emoji_events,
      message: 'Skill progressions (muscle-up, front lever…) will appear here.',
      milestone: 'M4 · Progress & Skills',
    );
  }
}
