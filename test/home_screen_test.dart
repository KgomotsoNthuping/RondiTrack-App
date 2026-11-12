import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/core/theme/ronditrack_theme.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/domain/home_repository.dart';
import 'package:ronditrack/features/home/presentation/home_screen.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

void main() {
  test('maps AsyncValue to the four Home states', () {
    expect(
      homeViewState(const AsyncLoading<List<HomeEntry>>()),
      isA<ScreenLoading<List<HomeEntry>>>(),
    );
    expect(
      homeViewState(const AsyncData(<HomeEntry>[])),
      isA<ScreenEmpty<List<HomeEntry>>>(),
    );
    expect(
      homeViewState(AsyncData([_entry])),
      isA<ScreenData<List<HomeEntry>>>(),
    );
    expect(
      homeViewState(
        AsyncError<List<HomeEntry>>(StateError('Offline'), StackTrace.empty),
      ),
      isA<ScreenFailure<List<HomeEntry>>>(),
    );
  });

  testWidgets('shows loading and then the member amounts', (tester) async {
    final pending = Completer<List<HomeEntry>>();
    final repository = _StubHomeRepository((_) => pending.future);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: RondiTrackTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete([_entry]);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Family Savers'), findsOneWidget);
    expect(find.text('Treasurer'), findsOneWidget);
    expect(find.text('R\u00A0500,00'), findsOneWidget);
    expect(find.text('R\u00A00,00'), findsOneWidget);
    expect(find.text('Arrears R\u00A025,00'), findsOneWidget);
    expect(find.text('30 Nov 2026'), findsOneWidget);
  });

  testWidgets('switching to Naledi shows the empty state', (tester) async {
    final repository = _StubHomeRepository(
      (userId) async => userId == 'naledi' ? [] : [_entry],
    );

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: RondiTrackTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Family Savers'), findsOneWidget);

    await tester.tap(find.byTooltip('Switch demo profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Naledi'));
    await tester.pumpAndSettle();

    expect(find.text('Signed in as Naledi'), findsOneWidget);
    expect(find.text('Family Savers'), findsNothing);
    expect(find.text('You have no stokvels yet.'), findsOneWidget);
    expect(
      find.text('Ask a stokvel administrator to send you an invite.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a failure and loads again on Retry', (tester) async {
    var calls = 0;
    final repository = _StubHomeRepository((_) async {
      calls += 1;
      if (calls == 1) {
        throw StateError('Offline');
      }
      return [_entry];
    });

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: RondiTrackTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load your stokvels.'), findsOneWidget);
    expect(find.text('Offline'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Family Savers'), findsOneWidget);
  });

  testWidgets('keeps the previous card visible during refresh', (tester) async {
    var calls = 0;
    final pending = Completer<List<HomeEntry>>();
    final repository = _StubHomeRepository((_) {
      calls += 1;
      return calls == 1 ? Future.value([_entry]) : pending.future;
    });

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: RondiTrackTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Refresh stokvels'));
    await tester.pump();

    expect(calls, 2);
    expect(find.text('Family Savers'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    pending.complete([_entry.copyWith(name: 'Family Savers updated')]);
    await tester.pumpAndSettle();

    expect(find.text('Family Savers updated'), findsOneWidget);
    expect(find.text('Family Savers'), findsNothing);
  });
}

final _entry = HomeEntry(
  membership: const Membership(
    stokvelId: 'family-savers',
    role: StokvelRole.treasurer,
  ),
  name: 'Family Savers',
  arrears: const Cents(2500),
  currentCycleNumber: 1,
  cycleStatus: CycleStatus.open,
  cycleDueDate: (year: 2026, month: 10, day: 31),
  paidThisCycle: const Cents(50_000),
  stillOwed: const Cents(0),
  nextPayoutDateUtc: DateTime.utc(2026, 11, 30),
);

class _StubHomeRepository implements HomeRepository {
  const new(this._fetch);

  final Future<List<HomeEntry>> Function(String userId) _fetch;

  @override
  Future<List<HomeEntry>> fetchHome(String userId) => _fetch(userId);
}