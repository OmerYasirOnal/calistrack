import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/app_user.dart';
import '../../onboarding/application/onboarding_answers.dart';
import '../data/user_repository.dart';

/// Edit the user-editable profile details (name / level / goals / body stats).
/// Seeded from the current profile; saves a targeted merge and pops.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({required this.profile, super.key});

  final AppUser profile;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profile.displayName);
  late final TextEditingController _height = TextEditingController(
    text: _fmt(widget.profile.heightCm),
  );
  late final TextEditingController _weight = TextEditingController(
    text: _fmt(widget.profile.weightKg),
  );
  late ExperienceLevel _level = widget.profile.level;
  late final Set<String> _goals = {...widget.profile.goals};
  bool _saving = false;

  static String _fmt(double? v) => v == null
      ? ''
      : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateDetails(
            widget.profile.uid,
            displayName: _name.text.trim(),
            level: _level,
            goals: _goals.toList(),
            heightCm: double.tryParse(_height.text.trim()),
            weightKg: double.tryParse(_weight.text.trim()),
          );
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not save your profile.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          TextField(
            controller: _name,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: Spacing.lg),
          Text('Experience', style: text.titleSmall),
          const SizedBox(height: Spacing.sm),
          SegmentedButton<ExperienceLevel>(
            segments: [
              for (final l in ExperienceLevel.values)
                ButtonSegment(value: l, label: Text(l.label)),
            ],
            selected: {_level},
            onSelectionChanged:
                _saving ? null : (s) => setState(() => _level = s.first),
          ),
          const SizedBox(height: Spacing.lg),
          Text('Goals', style: text.titleSmall),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            children: [
              for (final g in onboardingGoalOptions)
                FilterChip(
                  label: Text(g),
                  selected: _goals.contains(g),
                  onSelected: _saving
                      ? null
                      : (_) => setState(
                            () => _goals.contains(g)
                                ? _goals.remove(g)
                                : _goals.add(g),
                          ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: _NumField(
                  label: 'Height (cm)',
                  controller: _height,
                  enabled: !_saving,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _NumField(
                  label: 'Weight (kg)',
                  controller: _weight,
                  enabled: !_saving,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _saving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    required this.label,
    required this.controller,
    required this.enabled,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(labelText: label),
    );
  }
}
