import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/data/cached_account_store.dart';
import 'package:ronditrack/features/home/data/home_cache.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_cache.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

void main() {
  late AppDatabase database;
  late HomeCache home;
  late StokvelCache stokvels;
  late CurrentCycleCache cycles;
  late CachedAccountStore accounts;

  final updatedAt = DateTime.utc(2026, 11, 1, 10);

  const identity = AuthIdentity(
    userId: 'user-1',
    email: 'naledi@example.test',
    platformRole: 'Member',
    tokenId: 'must-not-be-cached',
  );

  const membership = Membership(
    stokvelId: 'stokvel-1',
    role: StokvelRole.member,
  );

  const cycle = ContributionCycle(
    id: 'cycle-1',
    number: 1,
    status: CycleStatus.open,
    targetAmount: Cents(250100),
    totalCollected: Cents(125050),
    amountOutstanding: Cents(125050),
    dueDate: (year: 2026, month: 11, day: 30),
    version: 3,
  );

  final entry = HomeEntry(
    membership: membership,
    name: 'Family Stokvel',
    arrears: const Cents(0),
    currentCycleNumber: 1,
    cycleStatus: CycleStatus.open,
    cycleDueDate: (year: 2026, month: 11, day: 30),
    paidThisCycle: const Cents(125050),
    stillOwed: const Cents(0),
    nextPayoutDateUtc: DateTime.utc(2026, 12, 1, 8),
  );

  final stokvel = Stokvel(
    membership: membership,
    name: 'Family Stokvel',
    monthlyContribution: const Cents(125050),
    memberCount: 2,
    currentPeriod: 1,
    totalPeriods: 2,
    currentCycle: cycle,
    rules: 'Pay before the due date.',
    contributions: [
      Contribution(
        id: 'contribution-1',
        cycleId: 'cycle-1',
        cycleNumber: 1,
        userId: 'user-1',
        memberName: 'Naledi',
        amount: const Cents(125050),
        status: ContributionStatus.paid,
        paidAtUtc: DateTime.utc(2026, 10, 31, 22, 30),
      ),
    ],
  );

  setUp(() {
    database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

    home = HomeCache(database);
    stokvels = StokvelCache(database);
    cycles = CurrentCycleCache(database);
    accounts = CachedAccountStore(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seed() async {
    final generation = database.generation;

    await accounts.remember(generation: generation, identity: identity);

    await home.replace(
      generation: generation,
      userId: identity.userId,
      entries: [entry],
      updatedAtUtc: updatedAt,
    );

    await stokvels.replace(
      generation: generation,
      userId: identity.userId,
      value: stokvel,
      updatedAtUtc: updatedAt,
    );
  }

  test('saved snapshots return domain objects and UTC timestamps', () async {
    await seed();

    final cachedHome = await home.read(identity.userId);
    final cachedStokvel = await stokvels.read(
      identity.userId,
      membership.stokvelId,
    );
    final cachedCycle = await cycles.read(
      identity.userId,
      membership.stokvelId,
    );

    expect(cachedHome?.value, [entry]);
    expect(cachedHome?.updatedAtUtc, updatedAt);
    expect(cachedHome?.updatedAtUtc.isUtc, isTrue);

    expect(cachedStokvel?.value, stokvel);
    expect(cachedStokvel?.value.monthlyContribution.value, 125050);

    expect(cachedCycle?.value, cycle);
    expect(cachedCycle?.value.version, 3);
  });

  test('an empty Home response remains a cached response', () async {
    expect(await home.read(identity.userId), isNull);

    await home.replace(
      generation: database.generation,
      userId: identity.userId,
      entries: [],
      updatedAtUtc: updatedAt,
    );

    final cached = await home.read(identity.userId);

    expect(cached, isNotNull);
    expect(cached?.value, isEmpty);
    expect(cached?.updatedAtUtc, updatedAt);
  });

  test('watchers started before writes receive their own changes', () async {
    final homeWatcher = StreamIterator(home.watch(identity.userId));
    final stokvelWatcher = StreamIterator(
      stokvels.watch(identity.userId, membership.stokvelId),
    );

    addTearDown(homeWatcher.cancel);
    addTearDown(stokvelWatcher.cancel);

    expect(await homeWatcher.moveNext(), isTrue);
    expect(homeWatcher.current, isNull);

    expect(await stokvelWatcher.moveNext(), isTrue);
    expect(stokvelWatcher.current, isNull);

    await home.replace(
      generation: database.generation,
      userId: identity.userId,
      entries: [entry],
      updatedAtUtc: updatedAt,
    );

    expect(await homeWatcher.moveNext(), isTrue);
    expect(homeWatcher.current?.value, [entry]);

    await stokvels.replace(
      generation: database.generation,
      userId: identity.userId,
      value: stokvel,
      updatedAtUtc: updatedAt,
    );

    expect(await stokvelWatcher.moveNext(), isTrue);
    expect(stokvelWatcher.current?.value, stokvel);
  });

  test('a cycle change also reaches the stokvel watcher', () async {
    await seed();

    final watcher = StreamIterator(
      stokvels.watch(identity.userId, membership.stokvelId),
    );

    addTearDown(watcher.cancel);

    expect(await watcher.moveNext(), isTrue);
    expect(watcher.current?.value.currentCycle, cycle);

    final refreshedCycle = cycle.copyWith(
      totalCollected: const Cents(250100),
      amountOutstanding: const Cents(0),
      version: 4,
    );

    await cycles.replace(
      generation: database.generation,
      userId: identity.userId,
      stokvelId: membership.stokvelId,
      value: refreshedCycle,
      updatedAtUtc: updatedAt.add(const Duration(minutes: 1)),
    );

    expect(await watcher.moveNext(), isTrue);
    expect(watcher.current?.value.currentCycle, refreshedCycle);
  });

  test('another account cannot read these snapshots', () async {
    await seed();

    expect(await home.read('user-2'), isNull);
    expect(await stokvels.read('user-2', membership.stokvelId), isNull);
    expect(await cycles.read('user-2', membership.stokvelId), isNull);
  });

  test('cached identity excludes token identity', () async {
    await seed();

    final cached = await accounts.read();

    expect(cached?.userId, identity.userId);
    expect(cached?.email, identity.email);
    expect(cached?.tokenId, isNull);
  });

  test('an account cannot replace another without cleanup', () async {
    await seed();

    await expectLater(
      accounts.remember(
        generation: database.generation,
        identity: const AuthIdentity(
          userId: 'user-2',
          email: 'other@example.test',
        ),
      ),
      throwsStateError,
    );

    expect((await accounts.read())?.userId, identity.userId);
  });

  test('cleanup removes every cached row and the last account', () async {
    await seed();

    await database.clearForSignOut();

    expect(await accounts.read(), isNull);
    expect(await home.read(identity.userId), isNull);
    expect(await stokvels.read(identity.userId, membership.stokvelId), isNull);
    expect(await cycles.read(identity.userId, membership.stokvelId), isNull);
  });

  test('a late response cannot write after cleanup', () async {
    final oldGeneration = database.generation;

    await database.clearForSignOut();

    final accepted = await home.replace(
      generation: oldGeneration,
      userId: identity.userId,
      entries: [entry],
      updatedAtUtc: updatedAt,
    );

    expect(accepted, isFalse);
    expect(await home.read(identity.userId), isNull);
  });

  test('removing a stokvel removes its cached cycle', () async {
    await seed();

    await stokvels.remove(
      generation: database.generation,
      userId: identity.userId,
      stokvelId: membership.stokvelId,
    );

    expect(await stokvels.read(identity.userId, membership.stokvelId), isNull);
    expect(await cycles.read(identity.userId, membership.stokvelId), isNull);
    expect(await home.read(identity.userId), isNotNull);
  });
}
