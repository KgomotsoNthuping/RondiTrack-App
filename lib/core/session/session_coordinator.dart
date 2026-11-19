import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/auth_api.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/refresh_token_store.dart';
import 'package:ronditrack/core/session/sign_out_marker.dart';

final class SessionCoordinator extends ChangeNotifier {
  SessionCoordinator({
    required AuthApi api,
    RefreshTokenStore? refreshTokenStore,
    SignOutMarker? signOutMarker,
    DateTime Function()? clock,
    this.refreshMargin = const Duration(seconds: 30),
  }) : _api = api,
       _store = refreshTokenStore,
       _marker = signOutMarker ?? MemorySignOutMarker(),
       _clock = clock ?? DateTime.now {
    if (!api.browserManagedCookies && refreshTokenStore == null) {
      throw ArgumentError('Native sessions require a refresh token store.');
    }
  }

  final AuthApi _api;
  final RefreshTokenStore? _store;
  final SignOutMarker _marker;
  final DateTime Function() _clock;
  final Duration refreshMargin;

  AuthState _state = const AuthRestoring();
  Future<void> _storageTail = Future<void>.value();
  Future<Result<void>>? _restoreFlight;
  Future<Result<void>>? _signOutFlight;
  Future<Result<AccessToken>>? _refreshFlight;
  Failure? _cleanupFailure;
  int _epoch = 0;
  bool _closed = false;
  bool _authenticating = false;

  AuthState get state => _state;

  int get epoch => _epoch;

  Future<Result<void>> restore() {
    if (_closed) {
      return Future.value(const Err(ServerFailure()));
    }

    if (_state is! AuthRestoring) {
      return Future.value(const Ok(null));
    }

    if (_restoreFlight case final pending?) {
      return pending;
    }

    late final Future<Result<void>> flight;

    flight = _restore(_epoch).whenComplete(() {
      if (identical(_restoreFlight, flight)) {
        _restoreFlight = null;
      }
    });

    _restoreFlight = flight;
    return flight;
  }

  Future<Result<void>> _restore(int generation) async {
    _publish(const AuthRestoring());

    try {
      final blocked = await _serial(_marker.read);

      if (!_current(generation)) {
        return const Err(_cancelled);
      }

      if (blocked) {
        _publish(const AuthSignedOut());
        return const Ok(null);
      }

      if (!_api.browserManagedCookies) {
        final stored = await _serial(_store!.read);

        if (!_current(generation)) {
          return const Err(_cancelled);
        }

        if (stored == null) {
          _publish(const AuthSignedOut());
          return const Ok(null);
        }
      }

      return switch (await refresh()) {
        Ok<AccessToken>() => const Ok(null),
        Err<AccessToken>(:final failure) => Err(failure),
      };
    } on Object {
      if (!_current(generation)) {
        return const Err(_cancelled);
      }

      const failure = ServerFailure();
      _publish(const AuthRestoring(failure: failure));
      return const Err(failure);
    }
  }

  Future<Result<void>> signIn({
    required String email,
    required String password,
  }) async {
    if (_closed) {
      return const Err(ServerFailure());
    }

    if (_authenticating || _state is! AuthSignedOut) {
      return const Err(
        RuleFailure(detail: 'Finish the current session first.'),
      );
    }

    _authenticating = true;
    final generation = ++_epoch;

    _api.cancelPending();
    _restoreFlight = null;
    _refreshFlight = null;

    try {
      await _signOutFlight;

      if (!_current(generation)) {
        return const Err(_cancelled);
      }

      if (_cleanupFailure case final failure?) {
        return Err(failure);
      }

      final result = await _api.signIn(email: email, password: password);

      if (!_current(generation)) {
        return const Err(_cancelled);
      }

      switch (result) {
        case Err<AuthTokens>(:final failure):
          _publish(AuthSignedOut(failure: failure));
          return Err(failure);

        case Ok<AuthTokens>(:final value):
          if (!await _persist(value, generation, signIn: true)) {
            return const Err(_cancelled);
          }

          _publishSignedIn(value, generation);
          return const Ok(null);
      }
    } on Object {
      if (!_current(generation)) {
        return const Err(_cancelled);
      }

      const failure = ServerFailure();
      await signOut(reason: failure);
      return const Err(failure);
    } finally {
      _authenticating = false;
    }
  }

  Future<Result<RegisteredAccount>> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    if (_closed) {
      return const Err(ServerFailure());
    }

    if (_authenticating || _state is! AuthSignedOut) {
      return const Err(
        RuleFailure(detail: 'Finish the current session first.'),
      );
    }

    _authenticating = true;
    final generation = _epoch;

    try {
      await _signOutFlight;

      if (!_current(generation)) {
        return const Err(_cancelled);
      }

      if (_cleanupFailure case final failure?) {
        return Err(failure);
      }

      final result = await _api.register(
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );

      return _current(generation) ? result : const Err(_cancelled);
    } on Object {
      return const Err(ServerFailure());
    } finally {
      _authenticating = false;
    }
  }

  Future<Result<AccessToken>> tokenForRequest() async {
    if (_state is AuthRestoring) {
      await restore();
    }

    final current = _state;

    if (current is AuthRestoring) {
      return Err(current.failure ?? const ServerFailure());
    }

    if (current is! AuthSignedIn) {
      return const Err(UnauthorizedFailure());
    }

    final threshold = _clock().toUtc().add(refreshMargin);

    if (!current.accessToken.expiresAtUtc.isAfter(threshold)) {
      return refresh();
    }

    return Ok(current.accessToken);
  }

  Future<Result<AccessToken>> refresh() {
    if (_closed || _state is AuthSignedOut) {
      return Future.value(const Err(UnauthorizedFailure()));
    }

    if (_refreshFlight case final pending?) {
      return pending;
    }

    late final Future<Result<AccessToken>> flight;

    flight = _refresh(_epoch).whenComplete(() {
      if (identical(_refreshFlight, flight)) {
        _refreshFlight = null;
      }
    });

    _refreshFlight = flight;
    return flight;
  }

  Future<Result<AccessToken>> _refresh(int generation) async {
    try {
      final stored = _api.browserManagedCookies
          ? null
          : await _serial(_store!.read);

      if (!_current(generation)) {
        return const Err(_cancelled);
      }

      if (!_api.browserManagedCookies && stored == null) {
        return _refreshFailed(const ServerFailure());
      }

      final result = await _api.refresh(refreshToken: stored);

      if (!_current(generation)) {
        return const Err(_cancelled);
      }

      switch (result) {
        case Err<AuthTokens>(:final failure):
          if (failure is UnauthorizedFailure) {
            await signOut(reason: failure);
            return Err(failure);
          }

          return _refreshFailed(failure);

        case Ok<AuthTokens>(:final value):
          final before = _state;

          if (before is AuthSignedIn &&
              before.identity.userId != value.identity.userId) {
            return _refreshFailed(const ServerFailure());
          }

          if (!await _persist(value, generation, signIn: false)) {
            return const Err(_cancelled);
          }

          return Ok(_publishSignedIn(value, generation));
      }
    } on Object {
      if (!_current(generation)) {
        return const Err(_cancelled);
      }

      return _refreshFailed(const ServerFailure());
    }
  }

  Result<AccessToken> _refreshFailed(Failure failure) {
    if (_state is AuthRestoring) {
      _publish(AuthRestoring(failure: failure));
    }

    return Err(failure);
  }

  Future<bool> _persist(
    AuthTokens tokens,
    int generation, {
    required bool signIn,
  }) {
    return _serial(() async {
      if (!_current(generation)) {
        return false;
      }

      if (!tokens.expiresAtUtc.isAfter(_clock().toUtc())) {
        throw const FormatException('The API returned an expired token.');
      }

      if (!_api.browserManagedCookies) {
        final refresh = tokens.refreshToken;

        if (refresh == null) {
          throw const FormatException('Missing refresh credentials.');
        }

        await _store!.write(refresh);
      }

      if (!_current(generation)) {
        return false;
      }

      if (signIn) {
        await _marker.write(false);
      }

      return _current(generation);
    });
  }

  AccessToken _publishSignedIn(AuthTokens tokens, int generation) {
    final access = AccessToken(
      value: tokens.accessToken,
      expiresAtUtc: tokens.expiresAtUtc.toUtc(),
      userId: tokens.identity.userId,
    );

    _publish(
      AuthSignedIn(
        identity: tokens.identity,
        accessToken: access,
        sessionId: generation,
      ),
    );

    return access;
  }

  Future<Result<void>> signOut({Failure? reason}) {
    if (_closed) {
      return Future.value(const Err(ServerFailure()));
    }

    if (_signOutFlight case final pending?) {
      return pending;
    }

    final generation = ++_epoch;

    _api.cancelPending();
    _restoreFlight = null;
    _refreshFlight = null;
    _publish(AuthSignedOut(failure: reason));

    late final Future<Result<void>> flight;

    flight = _signOut(generation).whenComplete(() {
      if (identical(_signOutFlight, flight)) {
        _signOutFlight = null;
      }
    });

    _signOutFlight = flight;
    return flight;
  }

  Future<Result<void>> _signOut(int generation) async {
    var cleanupFailed = false;

    final stored = await _serial<RefreshToken?>(() async {
      try {
        await _marker.write(true);
      } on Object {
        cleanupFailed = true;
      }

      if (_api.browserManagedCookies) {
        return null;
      }

      RefreshToken? token;

      try {
        token = await _store!.read();
      } on Object {
        token = null;
      }

      try {
        await _store!.clear();
      } on Object {
        cleanupFailed = true;
      }

      return token;
    });

    _cleanupFailure = cleanupFailed ? const ServerFailure() : null;

    try {
      await _api
          .logout(refreshToken: stored)
          .timeout(const Duration(seconds: 2));
    } on Object {}

    if (cleanupFailed) {
      const failure = ServerFailure();

      if (_current(generation)) {
        _publish(const AuthSignedOut(failure: failure));
      }

      return const Err(failure);
    }

    return const Ok(null);
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = Completer<T>();

    _storageTail = _storageTail.then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stack) {
        result.completeError(error, stack);
      }
    });

    return result.future;
  }

  bool _current(int generation) {
    return !_closed && generation == _epoch;
  }

  void _publish(AuthState value) {
    if (_closed) {
      return;
    }

    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _epoch++;
    _api.cancelPending();
    super.dispose();
  }
}

const _cancelled = OfflineFailure(isRead: false);
