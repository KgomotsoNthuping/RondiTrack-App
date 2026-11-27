import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/offline/cache_controller.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/core/offline/data/offline_database_provider.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_api.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/refresh_token_store.dart';
import 'package:ronditrack/core/session/session_access.dart';
import 'package:ronditrack/core/session/session_coordinator.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/core/session/session_persistence.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/domain/home_repository.dart';
import 'package:ronditrack/features/offline/application/offline_account_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

const testUserId = '11111111-1111-4111-8111-111111111111';
const testStokvelId = '22222222-2222-4222-8222-222222222222';
const testCycleId = '33333333-3333-4333-8333-333333333333';
final testNow = DateTime.utc(2030, 1, 1, 12);

const testIdentity = AuthIdentity(
  userId: testUserId,
  email: 'member@example.invalid',
);

const testHomeEntry = HomeEntry(
  membership: Membership(stokvelId: testStokvelId, role: StokvelRole.member),
  name: 'Test Savings',
  arrears: Cents(5000),
  currentCycleNumber: 1,
  cycleStatus: CycleStatus.open,
  paidThisCycle: Cents(0),
  stillOwed: Cents(10000),
);

const testStokvel = Stokvel(
  membership: Membership(stokvelId: testStokvelId, role: StokvelRole.member),
  name: 'Test Savings',
  monthlyContribution: Cents(10000),
  memberCount: 6,
  currentPeriod: 1,
  totalPeriods: 6,
  contributions: [],
  currentCycle: ContributionCycle(
    id: testCycleId,
    number: 1,
    status: CycleStatus.open,
    targetAmount: Cents(60000),
    totalCollected: Cents(10000),
    amountOutstanding: Cents(50000),
    version: 1,
  ),
  version: 1,
);

class MockHomeRepository extends Mock implements HomeRepository;

class MockStokvelRepository extends Mock implements StokvelRepository;

class MockAuthApi extends Mock implements AuthApi;

class MockSessionAccess extends Mock implements SessionAccess;

AuthTokens testTokens(String value) => AuthTokens(
  accessToken: value,
  expiresAtUtc: testNow.add(const Duration(minutes: 10)),
  identity: testIdentity,
  refreshToken: RefreshToken('refresh-$value'),
);

AppDatabase memoryDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

final class TestSession {
  new _(this.api, this.store, this.coordinator);

  final MockAuthApi api;
  final MemoryRefreshTokenStore store;
  final SessionCoordinator coordinator;

  static Future<TestSession> start({SessionPersistence? persistence}) async {
    final api = MockAuthApi();

    when(() => api.browserManagedCookies).thenReturn(false);
    when(
      () => api.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Ok(testTokens('old-token')));
    when(() => api.logout(refreshToken: any(named: 'refreshToken')))
        .thenAnswer((_) async => const Ok<void>(null));

    final store = MemoryRefreshTokenStore();
    final coordinator = SessionCoordinator(
      api: api,
      refreshTokenStore: store,
      persistence: persistence,
      clock: () => testNow,
    );

    await coordinator.restore();

    final result = await coordinator.signIn(
      email: testIdentity.email,
      password: 'test-only-password',
    );

    if (result is! Ok<void>) {
      coordinator.dispose();
      throw StateError('The test session could not sign in.');
    }

    return TestSession._(api, store, coordinator);
  }

  void dispose() => coordinator.dispose();
}

final class CacheHarness {
  new _(this.database, this.session, this.home, this.stokvel, this.container);

  final AppDatabase database;
  final TestSession session;
  final MockHomeRepository home;
  final MockStokvelRepository stokvel;
  final ProviderContainer container;

  OfflineAccountKey get account =>
      (userId: testUserId, sessionId: session.coordinator.epoch);

  CachedStokvelKey get stokvelKey =>
      (account: account, stokvelId: testStokvelId);

  static Future<CacheHarness> start() async {
    final database = memoryDatabase();
    final session = await TestSession.start();
    final home = MockHomeRepository();
    final stokvel = MockStokvelRepository();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        offlineDatabaseProvider.overrideWithValue(database),
        offlineCacheClockProvider.overrideWithValue(() => testNow),
        sessionCoordinatorProvider.overrideWithValue(session.coordinator),
        homeRepositoryProvider.overrideWithValue(home),
        stokvelRepositoryProvider.overrideWithValue(stokvel),
        cachedStokvelRepositoryProvider.overrideWithValue(stokvel),
      ],
    );

    return CacheHarness._(database, session, home, stokvel, container);
  }

  Future<void> close() async {
    container.dispose();
    session.dispose();
    await database.close();
  }
}

Future<void> waitForCache<T>(
  CacheController<T> controller,
  bool Function() ready,
) async {
  final reached = Completer<void>();

  void check() {
    if (!reached.isCompleted && ready()) {
      reached.complete();
    }
  }

  controller.addListener(check);

  try {
    check();
    await reached.future.timeout(const Duration(seconds: 3));
  } finally {
    controller.removeListener(check);
  }
}
