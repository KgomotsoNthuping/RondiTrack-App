import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/theme/ronditrack_theme.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/data/fake_home_repository.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/data/fake_stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_actions.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_detail_screen.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvels_screen.dart';

const _fixtures = FakeStokvelRepository(delay: Duration.zero);
const _homeFixtures = FakeHomeRepository(delay: Duration.zero);

final _config = AppConfig.parse(
  nativeFlavor: 'dev',
  configuredFlavor: 'dev',
  apiBaseUrl: 'http://10.0.2.2:5227',
);

void main() {
  test('separates IDs, shares fetches and disposes detail', () async {
    final calls = <String, int>{};
    final repository = _StubRepository((userId, id) {
      calls.update(id, (count) => count + 1, ifAbsent: () => 1);
      return _fixtures.fetchDetail(userId, id);
    });
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
        stokvelRepositoryProvider.overrideWithValue(repository),
      ],
    );

    const familyId = 'family-savers';
    final family = stokvelDetailProvider(familyId);
    final work = stokvelDetailProvider('work-savers');
    final first = container.listen(family, (_, _) {});
    final second = container.listen(family, (_, _) {});
    final other = container.listen(work, (_, _) {});

    await container.read(family.future);
    await container.read(work.future);

    final familyDetail = first.read().requireValue!;
    final workDetail = other.read().requireValue!;
    expect(familyDetail.stokvel.name, 'Family Savers');
    expect(second.read().requireValue, familyDetail);
    expect(workDetail.stokvel.name, 'Work Savers');
    expect(familyDetail.actions, contains(StokvelAction.closeCycle));
    expect(workDetail.actions, isNot(contains(StokvelAction.closeCycle)));
    expect(calls, {'family-savers': 1, 'work-savers': 1});

    first.close();
    await container.pump();
    expect(container.exists(family), isTrue);

    second.close();
    await container.pump();
    expect(container.exists(family), isFalse);
    expect(container.exists(work), isTrue);
    debugPrint('Disposed stokvel detail $familyId');

    final reopened = container.listen(family, (_, _) {});
    await container.read(family.future);
    expect(calls[familyId], 2);

    reopened.close();
    other.close();
  });

  test('the fake hides both missing and non-member stokvels', () async {
    expect(await _fixtures.fetchDetail('nandi', 'work-savers'), isNull);
    expect(await _fixtures.fetchDetail('nandi', 'missing'), isNull);
    expect(await _fixtures.fetchDetail('naledi', 'family-savers'), isNull);
  });

  testWidgets('switches to Work Savers loading on the next frame', (
    tester,
  ) async {
    _setViewport(tester, const Size(800, 1100));
    _setInitialLocation(
      tester,
      const StokvelDetailRoute(id: 'family-savers').location,
    );

    final pending = Completer<Stokvel?>();
    final repository = _StubRepository((userId, id) {
      return id == 'work-savers'
          ? pending.future
          : _fixtures.fetchDetail(userId, id);
    });

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(_homeFixtures),
          stokvelRepositoryProvider.overrideWithValue(repository),
        ],
        child: RondiTrackApp(config: _config),
      ),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(StokvelDetailScreen)));
    expect(find.text('Treasurer'), findsOneWidget);
    expect(find.text('Close cycle'), findsOneWidget);
    expect(find.text('Nandi'), findsOneWidget);
    expect(find.text('Due 31 Oct 2026'), findsOneWidget);
    expect(find.text('1 Nov 2026 00:30'), findsOneWidget);

    await tester.tap(find.byTooltip('Switch stokvel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work Savers'));
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, '/stokvels/work-savers');
    expect(find.text('Loading Work Savers'), findsOneWidget);
    expect(find.text('Nandi'), findsNothing);
    expect(find.text('Close cycle'), findsNothing);

    pending.complete(await _fixtures.fetchDetail('lerato', 'work-savers'));
    await tester.pumpAndSettle();

    expect(find.text('Loading Work Savers'), findsNothing);
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Upload proof'), findsOneWidget);
    expect(find.text('Close cycle'), findsNothing);
    expect(find.text('R\u00A0300,00'), findsOneWidget);
  });

  testWidgets('a direct cycle link keeps its stack when switching tabs', (
    tester,
  ) async {
    _setViewport(tester, const Size(550, 1100));
    const route = StokvelCycleRoute(
      id: 'family-savers',
      cycleId: 'family-cycle-1',
    );
    _setInitialLocation(tester, route.location);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(_homeFixtures),
          stokvelRepositoryProvider.overrideWithValue(_fixtures),
        ],
        child: RondiTrackApp(config: _config),
      ),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(StokvelCycleScreen)));
    expect(find.text('Cycle details'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, route.location);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Activity'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/activity');

    await tester.tap(find.widgetWithText(NavigationDestination, 'Stokvels'));
    await tester.pumpAndSettle();
    expect(find.text('Cycle details'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, route.location);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(StokvelDetailScreen), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/stokvels/family-savers');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(StokvelsScreen), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/stokvels');
  });

  testWidgets('shows not found for a cycle from another stokvel', (
    tester,
  ) async {
    _setInitialLocation(
      tester,
      const StokvelCycleRoute(
        id: 'family-savers',
        cycleId: 'work-cycle-1',
      ).location,
    );

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(_homeFixtures),
          stokvelRepositoryProvider.overrideWithValue(_fixtures),
        ],
        child: RondiTrackApp(config: _config),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not found'), findsOneWidget);
    expect(find.text('Contributions'), findsNothing);
  });

  testWidgets('shows empty detail when the stokvel has no activity', (
    tester,
  ) async {
    final repository = _StubRepository((userId, id) async {
      final stokvel = await _fixtures.fetchDetail(userId, id);
      return stokvel?.copyWith(currentCycle: null, contributions: const []);
    });

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(_homeFixtures),
          stokvelRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: RondiTrackTheme.light,
          home: const StokvelDetailScreen(stokvelId: 'family-savers'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No cycle or contributions yet.'), findsOneWidget);
    expect(
      find.text('Check again after your treasurer opens a cycle.'),
      findsOneWidget,
    );
  });

  testWidgets('shows not found for an unavailable stokvel ID', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(_homeFixtures),
          stokvelRepositoryProvider.overrideWithValue(_fixtures),
        ],
        child: MaterialApp(
          theme: RondiTrackTheme.light,
          home: const StokvelDetailScreen(stokvelId: 'missing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not found'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });

  testWidgets('shows a failure and recovers on Retry', (tester) async {
    var calls = 0;
    final repository = _StubRepository((userId, id) async {
      calls += 1;
      if (calls == 1) {
        throw StateError('Offline');
      }
      return _fixtures.fetchDetail(userId, id);
    });

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(_homeFixtures),
          stokvelRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: RondiTrackTheme.light,
          home: const StokvelDetailScreen(stokvelId: 'family-savers'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load this stokvel.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Could not load this stokvel.'), findsNothing);
    expect(find.text('Treasurer'), findsOneWidget);
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setInitialLocation(WidgetTester tester, String location) {
  final dispatcher = tester.binding.platformDispatcher;
  dispatcher.defaultRouteNameTestValue = location;
  addTearDown(dispatcher.clearDefaultRouteNameTestValue);
}

class _StubRepository implements StokvelRepository {
  const new(this._fetch);

  final Future<Stokvel?> Function(String userId, String stokvelId) _fetch;

  @override
  Future<Stokvel?> fetchDetail(String userId, String stokvelId) {
    return _fetch(userId, stokvelId);
  }
}