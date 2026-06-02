import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';

// Single reminder → single, stable notification id (replaced on reschedule).
const int _reminderId = 1001;
const String _channelId = 'workout_reminders';
const String _channelName = 'Workout reminders';
const String _channelDescription = 'Daily nudge to do your workout';

/// Used on `dart:io` targets. Reminders only actually schedule on Android/iOS;
/// on the test VM / desktop [isSupported] is false so every method is a graceful
/// no-op (no plugin calls), which is why widget tests need no override.
NotificationService createNotificationService(Ref ref) =>
    LocalNotificationService();

class LocalNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<void> initialize() async {
    if (!isSupported || _ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC if the device zone can't be resolved — the reminder
      // still fires daily, just anchored to UTC time-of-day.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Don't prompt at init — we request explicitly when the user opts in.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> applyReminder({required bool enabled, int? minutes}) async {
    // No device reminders here (desktop / test VM) — nothing to fail.
    if (!isSupported) return true;
    await initialize();
    // Always clear the existing schedule first so toggling off / changing the
    // time never leaves a stale notification — mirrors the single-reminder
    // model and makes this idempotent.
    await _plugin.cancel(id: _reminderId);
    // Turning off (or no time set) is a success: the desired state is achieved.
    if (!enabled || minutes == null) return true;
    // Enabling but the OS permission was denied — report failure so the caller
    // can keep the toggle honest rather than showing "on" while nothing fires.
    if (!await _ensurePermission()) return false;

    final when = tz.TZDateTime.from(
      nextReminderInstance(minutes, DateTime.now()),
      tz.local,
    );
    await _plugin.zonedSchedule(
      id: _reminderId,
      title: 'Time to train 💪',
      body: "Keep your streak alive — today's session is waiting.",
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Repeat every day at the same wall-clock time.
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  /// Requests the OS notification permission, returning whether it's granted.
  /// iOS and Android 13+ prompt; older Android grants implicitly.
  Future<bool> _ensurePermission() async {
    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return granted ?? true;
  }
}
