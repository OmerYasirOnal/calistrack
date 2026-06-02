import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';

/// Used on web / any non-`dart:io` target. Never touches the notifications
/// plugin.
NotificationService createNotificationService(Ref ref) =>
    const NoOpNotificationService();

class NoOpNotificationService implements NotificationService {
  const NoOpNotificationService();

  @override
  bool get isSupported => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> applyReminder({required bool enabled, int? minutes}) async =>
      true;
}
