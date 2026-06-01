import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

/// Program browser. Built out in M3 (T11/T12): preset Push/Pull/Legs/Core/Run
/// programs plus AI-generated programs, with detail + "start today".
class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Programs',
      icon: Icons.fitness_center,
      message: 'Preset and AI-generated programs will appear here.',
      milestone: 'M3 · Programs & Workout',
    );
  }
}
