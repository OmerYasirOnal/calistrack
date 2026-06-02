import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Web (and any non-io target) gets the no-op implementation; mobile/desktop/the
// test VM get the flutter_local_notifications-backed one. This keeps the web
// build (lib/preview.dart) free of the notifications plugin, which has no web
// support, and lets widget tests run without overriding the service.
import 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_io.dart';

/// Default reminder time (18:00) used when the user first enables it without a
/// previously-chosen time.
const int defaultReminderMinutes = 18 * 60;

/// A [TimeOfDay] for [minutes] past midnight (clamped to a valid time-of-day).
TimeOfDay reminderTimeOfDay(int minutes) {
  final clamped = minutes.clamp(0, 24 * 60 - 1);
  return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
}

/// The next wall-clock time a daily reminder set for [minutes] past midnight
/// should fire, relative to [now]: today at that time, or tomorrow if that
/// moment has already passed. Pure → unit-tested; the io impl maps the result
/// onto the local timezone for scheduling.
DateTime nextReminderInstance(int minutes, DateTime now) {
  final clamped = minutes.clamp(0, 24 * 60 - 1);
  var next = DateTime(
    now.year,
    now.month,
    now.day,
    clamped ~/ 60,
    clamped % 60,
  );
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
  return next;
}

/// Schedules the single daily workout reminder on supported platforms
/// (Android/iOS) and is a safe no-op everywhere else (web, desktop, tests), so
/// the rest of the app never depends on the plugin being present.
abstract interface class NotificationService {
  bool get isSupported;

  /// Initialize the plugin + timezone database (no-op when unsupported).
  /// Best-effort; never throws into app startup.
  Future<void> initialize();

  /// Cancel-then-(re)schedule the one daily reminder. Cancels when [enabled] is
  /// false or [minutes] is null; otherwise requests permission (if needed) and
  /// schedules a daily notification at [minutes] past local midnight. Idempotent
  /// — safe to call on every profile change / app launch. No-op when
  /// unsupported.
  Future<void> applyReminder({required bool enabled, int? minutes});
}

/// The active [NotificationService] — real on mobile, no-op elsewhere.
/// Overridable in tests.
final notificationServiceProvider =
    Provider<NotificationService>(createNotificationService);
