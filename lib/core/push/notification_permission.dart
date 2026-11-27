import 'package:ronditrack/core/push/notification_ports.dart';

enum PermissionOutcome {
  disabled,
  handled,
  notNow,
  granted,
  denied,
  unavailable,
  cancelled,
}

final class NotificationPermission {
  new({
    required this.enabled,
    required this.notifications,
    required this.preferences,
  });

  final bool enabled;
  final LocalNotifications notifications;
  final NotificationPreferences preferences;

  bool _busy = false;
  bool _handled = false;

  Future<PermissionOutcome> afterPayment({
    required Future<bool> Function() explain,
    required bool Function() isCurrent,
  }) async {
    if (!enabled || !notifications.enabled) {
      return PermissionOutcome.disabled;
    }

    if (_busy || _handled) {
      return PermissionOutcome.handled;
    }

    _busy = true;

    try {
      if (await preferences.handled()) {
        _handled = true;
        return PermissionOutcome.handled;
      }

      if (!isCurrent()) {
        return PermissionOutcome.cancelled;
      }

      final allowed = await notifications.allowed();

      _handled = true;
      await preferences.markHandled();

      if (!isCurrent()) {
        return PermissionOutcome.cancelled;
      }

      if (allowed) {
        return PermissionOutcome.granted;
      }

      if (!await explain()) {
        return PermissionOutcome.notNow;
      }

      if (!isCurrent()) {
        return PermissionOutcome.cancelled;
      }

      return await notifications.requestPermission()
          ? PermissionOutcome.granted
          : PermissionOutcome.denied;
    } on Object {
      _handled = true;
      return PermissionOutcome.unavailable;
    } finally {
      _busy = false;
    }
  }
}
