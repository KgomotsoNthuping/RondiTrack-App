import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/data/fake_stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_actions.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_detail_screen.dart';

const _fixtures = FakeStokvelRepository(delay: Duration.zero);
const _names = {
  'family-savers': 'Family Savers',
  'work-savers': 'Work Savers',
};

void main() {
  test('separates IDs, shares fetches and disposes detail', () async {
    final calls = <String, int>{};
    final repository = _StubRepository((userId, id) {
      calls.update(id, (count) => count + 1, ifAbsent: () => 1);
      return _fixtures.fetchDetail(userId, id);
    });
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [stokvelRepositoryProvider.overrideWithValue(repository)],
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
    expect(second.read().requireValue, same(familyDetail));
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

  testWidgets('switches to Work Savers loading on the next frame', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetPhysicalSize);

    final pending = Completer<Stokvel?>();
    final repository = _StubRepository((userId, id) {
      return id == 'work-savers'
          ? pending.future
          : _fixtures.fetchDetail(userId, id);
    });

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [stokvelRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: StokvelDetailScreen(
            initialStokvelId: 'family-savers',
            stokvelNames: _names,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Treasurer'), findsOneWidget);
    expect(find.text('Close cycle'), findsOneWidget);
    expect(find.text('Nandi'), findsOneWidget);
    expect(find.text('Due 31 Oct 2026'), findsOneWidget);
    expect(find.text('1 Nov 2026 00:30'), findsOneWidget);

    await tester.tap(find.byTooltip('Switch stokvel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work Savers'));
    await tester.pump();

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

  testWidgets('shows empty detail when the stokvel has no activity', (tester) async {
    final repository = _StubRepository((userId, id) async {
      final stokvel = await _fixtures.fetchDetail(userId, id);
      return stokvel?.copyWith(currentCycle: null, contributions: const []);
    });

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [stokvelRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: StokvelDetailScreen(
            initialStokvelId: 'family-savers',
            stokvelNames: _names,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No cycle or contributions yet.'), findsOneWidget);
    expect(find.text('Check again after your treasurer opens a cycle.'),
        findsOneWidget);
  });

  testWidgets('shows the same not-found state for an unavailable ID', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [stokvelRepositoryProvider.overrideWithValue(_fixtures)],
        child: const MaterialApp(
          home: StokvelDetailScreen(
            initialStokvelId: 'missing',
            stokvelNames: {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stokvel not found.'), findsOneWidget);
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
        overrides: [stokvelRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: StokvelDetailScreen(
            initialStokvelId: 'family-savers',
            stokvelNames: _names,
          ),
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

class _StubRepository implements StokvelRepository {
  const new(this._fetch);

  final Future<Stokvel?> Function(String userId, String stokvelId) _fetch;

  @override
  Future<Stokvel?> fetchDetail(String userId, String stokvelId) {
    return _fetch(userId, stokvelId);
  }
}