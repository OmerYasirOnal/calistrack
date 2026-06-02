import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/ads/application/ad_service.dart';
import 'features/notifications/application/notification_service.dart';
import 'features/profile/application/profile_providers.dart';
import 'firebase_options.dart';
import 'models/app_user.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init is best-effort: with the committed placeholder config it may
  // throw, which is fine for local UI work and CI. Real config (via
  // `flutterfire configure`) makes this succeed. We never crash the app on it.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Offline-first: Firestore's local cache serves reads and queues writes
    // when offline (a separate Hive mirror would be redundant for this data —
    // see docs/specs/2026-06-02-m6-polish-design.md). Mobile semantics (the app
    // targets iOS/Android); web uses a different persistence mechanism.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e, st) {
    debugPrint('Firebase init skipped/failed (expected with placeholder): $e');
    debugPrintStack(stackTrace: st);
  }

  final container = ProviderContainer();
  // Best-effort ads init: a no-op on web/desktop/tests, mobile-only otherwise.
  try {
    await container.read(adServiceProvider).initialize();
  } catch (e) {
    debugPrint('Ads init skipped/failed: $e');
  }
  // Best-effort notifications init (plugin + timezone). No-op on
  // web/desktop/tests, mobile-only otherwise.
  try {
    await container.read(notificationServiceProvider).initialize();
  } catch (e) {
    debugPrint('Notifications init skipped/failed: $e');
  }
  // Re-arm the daily reminder from the persisted profile (the source of truth)
  // whenever it loads/changes. The OS keeps same-device schedules across
  // launches, but this covers a reinstall / new device / OS-dropped alarm where
  // the profile says "on" but no schedule exists. applyReminder is idempotent;
  // dedup so we don't reschedule on unrelated profile edits.
  ({bool enabled, int? minutes})? lastReminder;
  container.listen<AsyncValue<AppUser?>>(
    currentUserProfileProvider,
    (_, next) {
      final p = next.valueOrNull;
      if (p == null) return;
      final key = (enabled: p.reminderEnabled, minutes: p.reminderMinutes);
      if (key == lastReminder) return;
      lastReminder = key;
      unawaited(
        container.read(notificationServiceProvider).applyReminder(
              enabled: p.reminderEnabled,
              minutes: p.reminderMinutes,
            ),
      );
    },
    fireImmediately: true,
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CalisTrackApp(),
    ),
  );
}
