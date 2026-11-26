import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/features/offline/application/offline_account_provider.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_cache.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';

import '../support/fixtures.dart';

void main() {
  late CacheHarness h;

  setUp(() async {
    h = await CacheHarness.start();
  });

  tearDown(() async {
    await h.close();
  });

  test('loading shares one repository request and saves detail', () async {
    final response = Completer<Stokvel?>();
    when(() => h.stokvel.fetchDetail(testUserId, testStokvelId))
        .thenAnswer((_) => response.future);

    final provider = cachedStokvelProvider(h.stokvelKey);
    final subscription = h.container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = h.container.read(provider);

    final first = controller.refresh();
    final second = controller.refresh();

    expect(controller.refreshing, isTrue);
    expect(controller.cached, isNull);
    expect(identical(first, second), isTrue);

    response.complete(testStokvel);
    await first;
    await waitForCache(controller, () => controller.cached != null);

    expect(controller.cached!.value, testStokvel);
    expect(controller.cached!.updatedAtUtc, testNow);
    expect(controller.refreshing, isFalse);
    expect(controller.failure, isNull);
    verify(() => h.stokvel.fetchDetail(testUserId, testStokvelId)).called(1);
  });

  test('failure on an empty cache is not retried automatically', () async {
    when(() => h.stokvel.fetchDetail(testUserId, testStokvelId))
        .thenThrow(const ServerFailure());

    final provider = cachedStokvelProvider(h.stokvelKey);
    final subscription = h.container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = h.container.read(provider);

    await controller.refresh();

    expect(controller.cached, isNull);
    expect(controller.failure, isA<ServerFailure>());
    expect(controller.refreshing, isFalse);
    verify(() => h.stokvel.fetchDetail(testUserId, testStokvelId)).called(1);
  });

  test('offline refresh retains the saved cycle and timestamp', () async {
    final savedAt = testNow.subtract(const Duration(hours: 1));
    await StokvelCache(h.database).replace(
      generation: h.database.generation,
      userId: testUserId,
      value: testStokvel,
      updatedAtUtc: savedAt,
    );
    when(() => h.stokvel.fetchDetail(testUserId, testStokvelId))
        .thenThrow(const OfflineFailure(isRead: true));

    final provider = cachedStokvelProvider(h.stokvelKey);
    final subscription = h.container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = h.container.read(provider);
    await waitForCache(controller, () => controller.cached != null);

    await controller.refresh();

    expect(controller.cached!.value, testStokvel);
    expect(controller.cached!.updatedAtUtc, savedAt);
    expect(controller.failure, isA<OfflineFailure>());
    verify(() => h.stokvel.fetchDetail(testUserId, testStokvelId)).called(1);
  });

  test('not found removes both cached detail and cycle', () async {
    await StokvelCache(h.database).replace(
      generation: h.database.generation,
      userId: testUserId,
      value: testStokvel,
      updatedAtUtc: testNow,
    );
    when(() => h.stokvel.fetchDetail(testUserId, testStokvelId))
        .thenAnswer((_) async => null);

    final provider = cachedStokvelProvider(h.stokvelKey);
    final subscription = h.container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = h.container.read(provider);
    await waitForCache(controller, () => controller.cached != null);

    await controller.refresh();

    expect(controller.cached, isNull);
    expect(controller.failure, isA<NotFoundFailure>());
    expect(
      await StokvelCache(h.database).read(testUserId, testStokvelId),
      isNull,
    );
    expect(
      await CurrentCycleCache(h.database).read(testUserId, testStokvelId),
      isNull,
    );
    verify(() => h.stokvel.fetchDetail(testUserId, testStokvelId)).called(1);
  });

  test('a late reply cannot save into the next session', () async {
    final response = Completer<Stokvel?>();
    when(() => h.stokvel.fetchDetail(testUserId, testStokvelId))
        .thenAnswer((_) => response.future);

    final provider = cachedStokvelProvider(h.stokvelKey);
    final subscription = h.container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = h.container.read(provider);
    final request = controller.refresh();

    await h.session.coordinator.signOut();
    await h.session.coordinator.signIn(
      email: testIdentity.email,
      password: 'test-only-password',
    );

    response.complete(testStokvel);
    await request;

    expect(controller.cached, isNull);
    expect(
      await StokvelCache(h.database).read(testUserId, testStokvelId),
      isNull,
    );
    verify(() => h.stokvel.fetchDetail(testUserId, testStokvelId)).called(1);
  });
}
