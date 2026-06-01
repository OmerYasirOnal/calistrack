import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

/// Progress charts. Built out in M4 (T15/T16): per-exercise reps/weight/volume
/// over time via fl_chart.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Progress',
      icon: Icons.show_chart,
      message: 'Your per-exercise progress charts will appear here.',
      milestone: 'M4 · Progress & Skills',
    );
  }
}
