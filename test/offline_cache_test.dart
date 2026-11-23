import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/offline/cache_controller.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/features/home/data/home_cache.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

void main() {
  late AppDatabase database;
  late HomeCache cache;

  final savedAt = DateTime.utc(2026, 11, 1, 10);
  final refreshedAt = DateTime.utc(2026, 11, 1, 11);

  const original = HomeEntry(
    membership: Membership(stokvelId: 'stokvel-1', role: StokvelRole.member),
    name: 'Family Stokvel',
    arrears: Cents(125050),
  );

  const refreshed = HomeEntry(
    membership: Membership(stokvelId: 'stokvel-1', role: StokvelRole.member),
    name: 'Family Stokvel',
    arrears: Cents(0),
  );

  setUp(() async {
    database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

    cache = HomeCache(database);

    await cache.replace(
      generation: database.generation,
      userId: 'user-1',
      entries: [original],
      updatedAtUtc: savedAt,
    );
  });

  tearDown(() async {
    await database.close();
  });

  CacheController<List<HomeEntry>> controller(
    Future<List<HomeEntry>> Function() load,
  ) {
    return CacheController<List<HomeEntry>>(
      cache: cache.watch('user-1'),
      load: load,
      save: (value, generation, at) => cache.replace(
        generation: generation,
        userId: 'user-1',
        entries: value,
        updatedAtUtc: at,
      ),
      remove: (generation) =>
          cache.remove(generation: generation, userId: 'user-1'),
      generation: () => database.generation,
      isCurrent: () => true,
      clock: () => refreshedAt,
    );
  }

  test('cached data is available while the network is waiting', () async {
    final response = Completer<List<HomeEntry>>();
    final subject = controller(() => response.future);

    addTearDown(subject.dispose);

    await cache.read('user-1');

    expect(subject.cached?.value, [original]);

    final request = subject.refresh();

    expect(subject.refreshing, isTrue);
    expect(subject.cached?.value, [original]);

    response.complete([refreshed]);
    await request;
    await cache.read('user-1');

    expect(subject.cached?.value, [refreshed]);
    expect(subject.cached?.updatedAtUtc, refreshedAt);
  });

  test('an offline failure preserves the cached data', () async {
    final subject = controller(
      () async => throw const OfflineFailure(isRead: true),
    );

    addTearDown(subject.dispose);

    await cache.read('user-1');
    await subject.refresh();

    expect(subject.cached?.value, [original]);
    expect(subject.cached?.updatedAtUtc, savedAt);
    expect(subject.failure, isA<OfflineFailure>());
    expect((await cache.read('user-1'))?.value, [original]);
  });

  test('a successful retry updates the cache and clears failure', () async {
    var reachable = false;

    final subject = controller(() async {
      if (!reachable) {
        throw const OfflineFailure(isRead: true);
      }

      return [refreshed];
    });

    addTearDown(subject.dispose);

    await cache.read('user-1');
    await subject.refresh();

    expect(subject.failure, isA<OfflineFailure>());

    reachable = true;

    await subject.refresh();
    await cache.read('user-1');

    expect(subject.failure, isNull);
    expect(subject.cached?.value, [refreshed]);
  });

  test('not found removes the cached response', () async {
    final subject = controller(() async => throw const NotFoundFailure());

    addTearDown(subject.dispose);

    await cache.read('user-1');
    await subject.refresh();

    expect(subject.cached, isNull);
    expect(subject.failure, isA<NotFoundFailure>());
    expect(await cache.read('user-1'), isNull);
  });

  test('concurrent refreshes share one request', () async {
    final response = Completer<List<HomeEntry>>();
    var calls = 0;

    final subject = controller(() {
      calls++;
      return response.future;
    });

    addTearDown(subject.dispose);

    final first = subject.refresh();
    final second = subject.refresh();

    expect(identical(first, second), isTrue);
    expect(calls, 1);

    response.complete([refreshed]);

    await first;
    await second;
  });
}
