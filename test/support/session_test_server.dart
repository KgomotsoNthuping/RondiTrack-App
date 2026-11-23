import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_api.dart';
import 'package:ronditrack/core/session/auth_models.dart';

final class RotatingAuthServer implements AuthApi, HttpClientAdapter {
  new({required this.clock, this.browserManagedCookies = false}) {
    _expires = clock().add(const Duration(minutes: 10));
  }

  final DateTime Function() clock;

  @override
  final bool browserManagedCookies;

  final spent = <String>{};
  final requests = <RequestOptions>[];
  final refreshStarted = Completer<void>();
  final delayed401Started = Completer<void>();
  final _requestWaiters = <(int, Completer<void>)>[];

  Completer<void>? refreshGate;
  Completer<void>? delayed401Gate;
  String? delayed401Path;
  String? acceptedAccessOverride;
  Failure? refreshFailure;
  Failure? logoutFailure;
  int? protectedStatus;
  int refreshCalls = 0;
  int logoutCalls = 0;
  int unauthorizedResponses = 0;
  bool revoked = false;

  int _rotation = 0;
  late DateTime _expires;

  String get currentRefresh => 'refresh-$_rotation';

  String get currentAccess => 'access-$_rotation';

  Future<void> waitForRequests(int count) {
    if (requests.length >= count) {
      return Future<void>.value();
    }

    final ready = Completer<void>();
    _requestWaiters.add((count, ready));

    return ready.future;
  }

  AuthTokens get _tokens => AuthTokens(
    accessToken: currentAccess,
    expiresAtUtc: _expires,
    identity: const AuthIdentity(
      userId: 'user-01',
      email: 'member@example.invalid',
    ),
    refreshToken: browserManagedCookies ? null : RefreshToken(currentRefresh),
  );

  @override
  Future<Result<AuthTokens>> signIn({
    required String email,
    required String password,
  }) async {
    _rotation = 0;
    spent.clear();
    revoked = false;
    acceptedAccessOverride = null;
    _expires = clock().add(const Duration(minutes: 10));

    return Ok(_tokens);
  }

  @override
  Future<Result<RegisteredAccount>> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    return Ok(
      RegisteredAccount(
        userId: 'new-user',
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        version: 1,
      ),
    );
  }

  @override
  Future<Result<AuthTokens>> refresh({RefreshToken? refreshToken}) async {
    refreshCalls++;

    if (refreshFailure case final failure?) {
      return Err(failure);
    }

    final presented = browserManagedCookies
        ? currentRefresh
        : refreshToken?.value;

    if (presented != null && spent.contains(presented)) {
      revoked = true;
      return const Err(UnauthorizedFailure());
    }

    if (revoked || presented != currentRefresh) {
      return const Err(UnauthorizedFailure());
    }

    spent.add(currentRefresh);
    _rotation++;
    acceptedAccessOverride = null;
    _expires = clock().add(const Duration(minutes: 10));

    final answer = Ok(_tokens);

    if (!refreshStarted.isCompleted) {
      refreshStarted.complete();
    }

    await refreshGate?.future;

    return answer;
  }

  @override
  Future<Result<void>> logout({RefreshToken? refreshToken}) async {
    logoutCalls++;

    if (logoutFailure case final failure?) {
      return Err(failure);
    }

    final presented = browserManagedCookies
        ? currentRefresh
        : refreshToken?.value;

    if (presented == currentRefresh || spent.contains(presented)) {
      revoked = true;
    }

    return const Ok(null);
  }

  @override
  void cancelPending() {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    for (final (count, ready) in _requestWaiters) {
      if (requests.length >= count && !ready.isCompleted) {
        ready.complete();
      }
    }

    _requestWaiters.removeWhere((entry) => entry.$2.isCompleted);

    final accepted = acceptedAccessOverride ?? currentAccess;

    final authorized =
        !revoked &&
        _expires.isAfter(clock()) &&
        options.headers['Authorization'] == 'Bearer $accepted';

    final status = protectedStatus ?? (authorized ? 200 : 401);

    if (status == 401) {
      unauthorizedResponses++;

      if (options.path == delayed401Path) {
        if (!delayed401Started.isCompleted) {
          delayed401Started.complete();
        }

        await delayed401Gate?.future;
      }
    }

    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
