import 'dart:async';

import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/push/device_api.dart';
import 'package:ronditrack/core/push/installation_messaging.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_devices.dart';

final class DeviceSession implements SessionDevices {
  new({
    required InstallationMessaging messaging,
    required DeviceApi api,
    DateTime Function()? clock,
  }) : _messaging = messaging,
       _api = api,
       _clock = clock ?? DateTime.now {
    _subscription = messaging.onRegistered.listen((id) {
      if (_closed || !RegExp(r'^[A-Za-z0-9_-]{1,256}$').hasMatch(id)) {
        return;
      }

      _installationId = id;
      unawaited(_queue(_postCurrent));
    }, onError: (Object _, StackTrace _) {});
  }

  final InstallationMessaging _messaging;
  final DeviceApi _api;
  final DateTime Function() _clock;

  late final StreamSubscription<String> _subscription;

  Future<void> _tail = Future<void>.value();
  AuthSignedIn? _owner;
  String? _installationId;
  (String, int, String)? _sent;
  int _revision = 0;
  bool _closed = false;

  @override
  bool get enabled => !_closed && _messaging.enabled;

  @override
  Future<void> synchronize(AuthState state) {
    if (!enabled) {
      return Future<void>.value();
    }

    final previous = _owner;

    if (state is! AuthSignedIn) {
      _owner = null;
      _installationId = null;
      _sent = null;
      _revision++;
      _api.cancelPending();

      return Future<void>.value();
    }

    final changed =
        previous?.identity.userId != state.identity.userId ||
        previous?.sessionId != state.sessionId;

    _owner = state;

    if (changed) {
      _revision++;
      _sent = null;
      _api.cancelPending();
    }

    final revision = _revision;
    final register = changed || _installationId == null;

    return _queue(() async {
      if (!_current(revision)) {
        return;
      }

      if (register) {
        await _messaging.register();
      }

      if (_current(revision)) {
        await _postCurrent();
      }
    });
  }

  bool _current(int revision) =>
      !_closed && _owner != null && revision == _revision;

  AccessToken? _access(AuthSignedIn? owner) {
    final access = owner?.currentAccessToken;

    if (owner == null ||
        owner.failure is UnauthorizedFailure ||
        access == null ||
        access.userId != owner.identity.userId ||
        !access.expiresAtUtc.isAfter(_clock().toUtc())) {
      return null;
    }

    return access;
  }

  Future<void> _postCurrent() async {
    final owner = _owner;
    final id = _installationId;
    final access = _access(owner);

    if (_closed || owner == null || id == null || access == null) {
      return;
    }

    final stamp = (owner.identity.userId, owner.sessionId, id);

    if (_sent == stamp) {
      return;
    }

    final revision = _revision;
    final accepted = await _api.register(id, access);

    if (accepted && _current(revision) && _installationId == id) {
      _sent = stamp;
    }
  }

  @override
  Future<void> beforeSignOut(AuthState state) {
    if (!enabled) {
      return Future<void>.value();
    }

    final id = _installationId;
    final access = _access(state is AuthSignedIn ? state : _owner);

    _owner = null;
    _installationId = null;
    _sent = null;
    _revision++;
    _api.cancelPending();

    final deletion = _forget(id, access);

    return _queue(() async {
      await deletion;
      await _messaging.unregister();
    });
  }

  Future<void> _forget(String? id, AccessToken? access) async {
    if (id == null || access == null) {
      return;
    }

    try {
      await _api.forget(id, access).timeout(const Duration(seconds: 2));
    } on Object {
      _api.cancelPending();
    }
  }

  Future<void> _queue(Future<void> Function() action) {
    final result = _tail.then((_) async {
      if (_closed) {
        return;
      }

      try {
        await action();
      } on Object {}
    });

    _tail = result;
    return result;
  }

  void dispose() {
    _closed = true;
    _owner = null;
    _revision++;
    _api.cancelPending();
    unawaited(_subscription.cancel());
  }
}
