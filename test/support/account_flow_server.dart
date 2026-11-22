import 'dart:async';

import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_api.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/features/home/data/fake_home_repository.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/domain/home_repository.dart';
import 'package:ronditrack/features/invites/domain/invite_repository.dart';
import 'package:ronditrack/features/payouts/data/fake_payout_repository.dart';
import 'package:ronditrack/features/payouts/domain/payout_order.dart';
import 'package:ronditrack/features/payouts/domain/payout_repository.dart';
import 'package:ronditrack/features/stokvels/data/fake_stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_repository.dart';

final class AccountFlowServer implements AuthApi, InviteRepository {
  String userId = 'naledi';
  String email = 'naledi@ronditrack.co.za';

  final joined = <String>{};

  int joins = 0;
  int previews = 0;
  int registrations = 0;
  int _tokens = 0;

  bool loseJoinResponse = false;
  bool conflictOnJoin = false;

  Completer<void>? restoreGate;
  void Function()? onLogout;

  HomeRepository get home => _Home(this);

  StokvelRepository get stokvels => _Stokvels(this);

  PayoutRepository get payouts => _Payouts(this);

  bool get nalediJoined => joined.contains('naledi');

  @override
  bool get browserManagedCookies => false;

  AuthTokens get _session => AuthTokens(
    accessToken: 'test-access-$userId-${_tokens++}',
    expiresAtUtc: DateTime.utc(2099),
    identity: AuthIdentity(
      userId: userId,
      email: email,
      platformRole: 'Member',
    ),
    refreshToken: RefreshToken('test-refresh-$userId-$_tokens'),
  );

  @override
  Future<Result<AuthTokens>> signIn({
    required String email,
    required String password,
  }) async {
    this.email = email;

    userId = email.startsWith('lerato@')
        ? 'lerato'
        : email.startsWith('nandi@')
        ? 'nandi'
        : 'naledi';

    return Ok(_session);
  }

  @override
  Future<Result<RegisteredAccount>> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    registrations++;

    return Ok(
      RegisteredAccount(
        userId: 'naledi',
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        version: 1,
      ),
    );
  }

  @override
  Future<Result<AuthTokens>> refresh({RefreshToken? refreshToken}) async {
    await restoreGate?.future;

    return Ok(_session);
  }

  @override
  Future<Result<void>> logout({RefreshToken? refreshToken}) async {
    onLogout?.call();

    return const Err(OfflineFailure(isRead: false));
  }

  @override
  void cancelPending() {}

  @override
  Future<Result<InvitePreview>> preview(String code) async {
    previews++;

    if (code == 'expired') {
      return const Err(RuleFailure(detail: expiredInviteMessage));
    }

    if (code != 'family-invite') {
      return const Err(NotFoundFailure());
    }

    return Ok(
      InvitePreview(
        stokvelId: 'family-savers',
        name: 'Family Savers',
        alreadyMember: userId != 'naledi' || joined.contains(userId),
      ),
    );
  }

  @override
  Future<Result<JoinedInvite>> join(String code) async {
    joins++;
    joined.add(userId);

    if (conflictOnJoin) {
      return const Err(ConflictFailure());
    }

    if (loseJoinResponse) {
      return const Err(OfflineFailure(isRead: false));
    }

    return const Ok(
      JoinedInvite(stokvelId: 'family-savers', name: 'Family Savers'),
    );
  }
}

final class _Home implements HomeRepository {
  const _Home(this.server);

  final AccountFlowServer server;

  @override
  Future<List<HomeEntry>> fetchHome(String userId) {
    return FakeHomeRepository(
      delay: Duration.zero,
      nalediJoinedFamily: server.nalediJoined,
    ).fetchHome(userId);
  }
}

final class _Stokvels implements StokvelCycleRepository {
  const _Stokvels(this.server);

  final AccountFlowServer server;

  @override
  Future<Stokvel?> fetchDetail(String userId, String stokvelId) {
    return FakeStokvelRepository(
      delay: Duration.zero,
      workDelay: Duration.zero,
      nalediJoinedFamily: server.nalediJoined,
    ).fetchDetail(userId, stokvelId);
  }

  @override
  Future<Stokvel?> fetchCycleDetail(
    String userId,
    String stokvelId,
    String cycleId,
  ) async {
    final stokvel = await fetchDetail(userId, stokvelId);

    return stokvel?.currentCycle?.id == cycleId ? stokvel : null;
  }
}

final class _Payouts implements PayoutRepository {
  const _Payouts(this.server);

  final AccountFlowServer server;

  @override
  Future<PayoutOrder> fetchOrder(String userId, PayoutCycleKey cycle) {
    return FakePayoutRepository(
      stokvelRepository: server.stokvels,
      nalediJoinedFamily: server.nalediJoined,
    ).fetchOrder(userId, cycle);
  }
}
