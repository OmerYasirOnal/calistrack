import 'package:calistrack/features/notifications/application/notification_service.dart';
import 'package:calistrack/features/notifications/application/notification_service_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextReminderInstance', () {
    test('returns today when the time is still ahead', () {
      final now = DateTime(2026, 6, 2, 10, 0);
      expect(
        nextReminderInstance(18 * 60, now),
        DateTime(2026, 6, 2, 18, 0),
      );
    });

    test('rolls to tomorrow when the time has passed', () {
      final now = DateTime(2026, 6, 2, 20, 0);
      expect(
        nextReminderInstance(18 * 60, now),
        DateTime(2026, 6, 3, 18, 0),
      );
    });

    test('rolls to tomorrow when exactly at the time (never schedules in past)',
        () {
      final now = DateTime(2026, 6, 2, 18, 0);
      expect(
        nextReminderInstance(18 * 60, now),
        DateTime(2026, 6, 3, 18, 0),
      );
    });

    test('clamps an out-of-range minute to the last valid time-of-day', () {
      final now = DateTime(2026, 6, 2, 0, 0);
      expect(
        nextReminderInstance(5000, now),
        DateTime(2026, 6, 2, 23, 59),
      );
    });
  });

  group('reminderTimeOfDay', () {
    test('maps minutes-past-midnight to a TimeOfDay', () {
      expect(reminderTimeOfDay(450), const TimeOfDay(hour: 7, minute: 30));
      expect(reminderTimeOfDay(0), const TimeOfDay(hour: 0, minute: 0));
    });
  });

  test('defaultReminderMinutes is 18:00', () {
    expect(defaultReminderMinutes, 18 * 60);
  });

  group('NoOpNotificationService', () {
    test('is unsupported and every method is a safe no-op', () async {
      const service = NoOpNotificationService();
      expect(service.isSupported, false);
      await service.initialize();
      await service.applyReminder(enabled: true, minutes: 480);
      await service.applyReminder(enabled: false, minutes: null);
    });
  });
}
