import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Shared email field with validation, reused by login and register.
class EmailField extends StatelessWidget {
  const EmailField({required this.controller, this.enabled = true, super.key});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Email is required';
        if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
        return null;
      },
    );
  }
}

/// Shared password field with a minimum-length validator.
class PasswordField extends StatelessWidget {
  const PasswordField({
    required this.controller,
    this.enabled = true,
    this.label = 'Password',
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: true,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
      ),
      validator: (value) {
        final v = value ?? '';
        if (v.isEmpty) return 'Password is required';
        if (v.length < 6) return 'At least 6 characters';
        return null;
      },
    );
  }
}

/// Turns auth exceptions into human-readable messages for SnackBars.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'That email address is invalid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Incorrect email or password.',
      'email-already-in-use' ||
      'credential-already-in-use' =>
        'That email already has an account — sign in with it instead.',
      'weak-password' => 'Please choose a stronger password.',
      'network-request-failed' => 'Network error. Check your connection.',
      _ => error.message ?? 'Authentication failed.',
    };
  }
  return 'Something went wrong. Please try again.';
}
