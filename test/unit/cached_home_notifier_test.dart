import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/features/home/data/home_cache.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/offline/application/offline_account_provider.dart';

import '../support/fixtures.dart';

void main() {
  late CacheHarness h;

  setUp(() async {
    h = await CacheHarness.start();
  });

  tearDown(() async {
    await h.close();
  });

  test('loading shares one repository request and saves data', () async {
    final response = Completer<List<HomeEntry>>();
    when(() => h.home.fetchHome(testUserId)).thenAnswer((_) => response.future);

    final provider = cachedHomeProvider(h.account);
    final subscription = h.container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = h.container.read(provider);

    final first = controller.refresh();
    final second = controller.refresh();

    expect(controller.refreshing, isTrue);
    expect(controller.cached, isNull);
    expect(identical(first, second), isTrue);

    response.complete([testHomeEntry]);
    await first;
    await waitForCache(controller, () => controller.cached != null);

    expect(controller.refreshing, isFalse);
    expect(controller.cached!.value, [testHomeEntry]);
    expect(controller.cached!.updatedAtUtc, testNow);
    expect(controller.failure, isNull);
    verify(() => h.home.fetchHome(testUserId)).called(1);
  });

  test('an empty cache exposes failure until an explicit retry', () async {
    when(() => h.home.fetchHome(testUserId))
        .thenThrow(const OfflineFailure(isRead: true));

    final provider = cachedHomeProvider(h.account);
    final subscription = h.container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = h.container.read(provider);

    await controller.refresh();

    expect(controller.cached, isNull);
    expect(controller.failure, isA<OfflineFailure>());
    expect(controller.refreshing, isFalse);
    verify(() => h.home.fetchHome(testUserId)).called(1);

    when(() => h.home.fetchHome(testUserId)).thenAnswer((_) async => []);

    await controller.refresh();
    await waitForCache(controller, () => controller.cached != null);

    expect(controller.cached!.value, isEmpty);
    expect(controller.failure, isNull);
    verify(() => h.home.fetchHome(testUserId)).called(1);
  });

  test('failed refresh preserves cached money and timestamp', () async {
    final savedAt = testNow.subtract(const Duration(hours: 1));

    await HomeCache(h.database).replace(
      generation: h.database.generation,
      userId: testUserId,
      entries: [testHomeEntry],
      updatedAtUtc: savedAt,
    );
    when(() => h.home.fetchHome(testUserId))
        .thenThrow(const OfflineFailure(isRead: true));

    final provider = cachedHomeProvider(h.account);
    final subscription = h.container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = h.container.read(provider);
    await waitForCache(controller, () => controller.cached != null);

    await controller.refresh();

    expect(controller.cached!.value, [testHomeEntry]);
    expect(controller.cached!.updatedAtUtc, savedAt);
    expect(controller.failure, isA<OfflineFailure>());
    verify(() => h.home.fetchHome(testUserId)).called(1);
  });
}
