import 'dart:async';

import 'package:ronditrack/core/push/notification_ports.dart';
import 'package:ronditrack/core/push/push_target.dart';
import 'package:ronditrack/core/session/auth_state.dart';

final class PushRuntime {
  PushRuntime({required this.messages, required this.notifications});

  factory PushRuntime.disabled() => PushRuntime(
    messages: const NoopPushMessages(),
    notifications: const NoopLocalNotifications(),
  );

  final PushMessages messages;
  final LocalNotifications notifications;

  final _taps = StreamController<PushTarget>.broadcast(sync: true);
  final _updates = StreamController<PushTarget>.broadcast(sync: true);
  final _subscriptions = <StreamSubscription<dynamic>>[];

  (String, int)? _account;
  PushTarget? _pending;
  PushTarget? initialTarget;

  bool _started = false;
  bool _closed = false;

  bool get enabled => !_closed && messages.enabled;

  Stream<PushTarget> get taps => _taps.stream;

  Stream<PushTarget> get updates => _updates.stream;

  Future<void> start() async {
    if (_started || !enabled) {
      return;
    }

    _started = true;

    _subscriptions.addAll([
      messages.foreground.listen(
        (data) => unawaited(_foreground(data)),
        onError: (Object _, StackTrace _) {},
      ),
      messages.opened.listen(
        (data) => _tap(PushTarget.parse(data)),
        onError: (Object _, StackTrace _) {},
      ),
      notifications.opened.listen(
        (data) => _tap(PushTarget.decode(data)),
        onError: (Object _, StackTrace _) {},
      ),
    ]);

    try {
      await notifications.initialize().timeout(const Duration(seconds: 2));
    } on Object {}

    final values = await Future.wait<Object?>([
      _safe(messages.initial),
      _safe(notifications.initialPayload),
    ]);

    initialTarget =
        _pending ??
        PushTarget.parse(values[0]) ??
        PushTarget.decode(values[1] as String?);

    _pending = null;
  }

  Future<T?> _safe<T>(Future<T> Function() read) async {
    try {
      return await read().timeout(const Duration(seconds: 2));
    } on Object {
      return null;
    }
  }

  void synchronize(AuthState? state) {
    final next = state is AuthSignedIn
        ? (state.identity.userId, state.sessionId)
        : null;

    if (_account != null && _account != next) {
      _pending = null;
      unawaited(_clear());
    }

    _account = next;
  }

  Future<void> _clear() async {
    try {
      await notifications.clear();
    } on Object {}
  }

  void _tap(PushTarget? target) {
    if (_closed || target == null) {
      return;
    }

    _pending = target;
    _taps.add(target);
  }

  PushTarget? takePending() {
    final target = _pending;
    _pending = null;
    return target;
  }

  Future<void> _foreground(Map<String, Object?> data) async {
    final account = _account;
    final target = PushTarget.parse(data);

    if (_closed || account == null || target == null) {
      return;
    }

    _updates.add(target);

    try {
      if (notifications.enabled &&
          await notifications.allowed() &&
          !_closed &&
          _account == account) {
        await notifications.show(target);

        if (_closed || _account != account) {
          await _clear();
        }
      }
    } on Object {}
  }

  Future<void> dispose() async {
    _closed = true;

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }

    await _taps.close();
    await _updates.close();
  }
}
