import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

/// Today's workout. Built out in M3 (T13/T14): shows the active program's
/// session for the day with a per-exercise set-logging checklist.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Today',
      icon: Icons.today,
      message: "Today's workout will appear here.",
      milestone: 'M3 · Programs & Workout',
    );
  }
}
