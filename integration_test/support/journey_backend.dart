import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_api.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/domain/home_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

final class JourneyBackend implements AuthApi, HttpClientAdapter {
  static const userId = '11111111-1111-4111-8111-111111111111';
  static const stokvelId = '22222222-2222-4222-8222-222222222222';
  static const cycleId = '33333333-3333-4333-8333-333333333333';
  static const contributionId = '44444444-4444-4444-8444-444444444444';
  static const email = 'journey.member@example.invalid';
  static const password = 'Journey-test-password';
  static const name = 'Journey Savers';
  static const memberName = 'Journey Member';

  final now = DateTime.now().toUtc();
  final logoutCompleted = Completer<void>();
  final unexpectedRequests = <String>[];
  final _receipts = <String, ({String body, Map<String, Object?> data})>{};

  bool _authenticated = false;
  int signInCalls = 0;
  int paymentCalls = 0;

  int get contributionCount => _receipts.length;

  int get paidCents => _receipts.isEmpty
      ? 0
      : _receipts.values.single.data['amountInCents']! as int;

  String get _stock => '/api/v1/stokvels/$stokvelId';

  @override
  bool get browserManagedCookies => false;

  AuthTokens get _tokens => AuthTokens(
    accessToken: 'journey-access',
    expiresAtUtc: now.add(const Duration(hours: 1)),
    identity: const AuthIdentity(
      userId: userId,
      email: email,
      platformRole: 'Member',
    ),
    refreshToken: const RefreshToken('journey-refresh'),
  );

  @override
  Future<Result<AuthTokens>> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;

    if (email != JourneyBackend.email || password != JourneyBackend.password) {
      return const Err(UnauthorizedFailure());
    }

    _authenticated = true;
    return Ok(_tokens);
  }

  @override
  Future<Result<AuthTokens>> refresh({RefreshToken? refreshToken}) async {
    if (!_authenticated || refreshToken?.value != 'journey-refresh') {
      return const Err(UnauthorizedFailure());
    }

    return Ok(_tokens);
  }

  @override
  Future<Result<RegisteredAccount>> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async =>
      const Err(RuleFailure(detail: 'Registration is outside this test.'));

  @override
  Future<Result<void>> logout({RefreshToken? refreshToken}) async {
    _authenticated = false;

    if (!logoutCompleted.isCompleted) {
      logoutCompleted.complete();
    }

    return const Ok(null);
  }

  @override
  void cancelPending() {}

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!_authenticated ||
        options.headers['Authorization'] != 'Bearer journey-access') {
      return _json(401, {});
    }

    if (options.method == 'GET' && options.path == _stock) {
      return _json(200, {
        'id': stokvelId,
        'name': name,
        'role': 'Member',
        'monthlyContributionInCents': 10000,
        'memberCount': 6,
        'currentPeriod': 1,
        'totalPeriods': 6,
        'rules': 'Synthetic integration-test data.',
        'currentCycle': {
          'id': cycleId,
          'cycleNumber': 1,
          'status': 'Open',
          'targetAmountInCents': 60000,
          'totalCollectedInCents': paidCents,
          'amountOutstandingInCents': 60000 - paidCents,
          'dueDate': '2030-01-31',
        },
      });
    }

    if (options.method == 'GET' && options.path == '$_stock/cycles/$cycleId') {
      return _json(200, {
        'id': cycleId,
        'stokvelId': stokvelId,
        'cycleNumber': 1,
        'status': 'Open',
        'targetAmount': 600,
        'totalCollectedInCents': paidCents,
        'version': contributionCount + 1,
        'dueDate': '2030-01-31',
      });
    }

    if (options.method == 'GET' && options.path == '$_stock/contributions') {
      return _json(200, {
        'items': _receipts.values.map((receipt) => receipt.data).toList(),
        'nextPageToken': null,
      });
    }

    if (options.method == 'POST' &&
        options.path == '$_stock/cycles/$cycleId/contributions') {
      paymentCalls++;

      final key = options.headers['Idempotency-Key'];
      final body = options.data;

      if (key is! String || key.isEmpty || body is! String) {
        return _json(400, {'detail': 'A frozen payment and key are required.'});
      }

      final previous = _receipts[key];

      if (previous != null) {
        return previous.body == body
            ? _json(201, previous.data)
            : _json(409, {'detail': 'The key belongs to another body.'});
      }

      if (_receipts.isNotEmpty) {
        return _json(409, {'detail': 'Already paid for this cycle.'});
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;

      if (decoded['userId'] != userId || decoded['amountInCents'] != 10000) {
        return _json(422, {'detail': 'This journey expects a R100 payment.'});
      }

      final data = <String, Object?>{
        'id': contributionId,
        'userId': userId,
        'stokvelId': stokvelId,
        'contributionCycleId': cycleId,
        'cycleNumber': 1,
        'memberName': memberName,
        'amountInCents': 10000,
        'status': 'Paid',
        'paidAtUtc': now.toIso8601String(),
      };

      _receipts[key] = (body: body, data: data);
      return _json(201, data);
    }

    unexpectedRequests.add('${options.method} ${options.path}');
    return _json(500, {'detail': 'Unexpected test request.'});
  }

  ResponseBody _json(int status, Object? value) => ResponseBody.fromString(
    jsonEncode(value),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

final class JourneyHomeRepository implements HomeRepository {
  new(this.backend);

  final JourneyBackend backend;

  @override
  Future<List<HomeEntry>> fetchHome(String userId) async {
    if (userId != JourneyBackend.userId) {
      throw const ForbiddenFailure();
    }

    return [
      HomeEntry(
        membership: const Membership(
          stokvelId: JourneyBackend.stokvelId,
          role: StokvelRole.member,
        ),
        name: JourneyBackend.name,
        arrears: const Cents(0),
        currentCycleNumber: 1,
        cycleStatus: CycleStatus.open,
        cycleDueDate: (year: 2030, month: 1, day: 31),
        paidThisCycle: Cents(backend.paidCents),
        stillOwed: Cents(10000 - backend.paidCents),
      ),
    ];
  }
}
