import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/experimental/scope.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/core/theme/ronditrack_theme.dart';
import 'package:ronditrack/features/contributions/application/contribution_history_controller.dart';
import 'package:ronditrack/features/contributions/domain/contribution_history.dart';
import 'package:ronditrack/features/contributions/presentation/contribution_history_list.dart';
import 'package:ronditrack/features/contributions/presentation/contribution_history_screen.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

import '../support/assignment_12_1_fixtures.dart';
import '../support/scripted_http_adapter.dart';

@Dependencies([homeRepository])
void main() {
  testWidgets('the real history screen rebuilds only the changed row', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(500, 1400);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = await TestSession.start();
    final response = Completer<ResponseBody>();
    var calls = 0;

    final adapter = ScriptedHttpAdapter((request) {
      if (request.path.endsWith('/cycles')) {
        return jsonResponse(200, [
          {'id': testCycleId, 'cycleNumber': 1},
        ]);
      }

      if (request.path.endsWith('/members')) {
        return jsonResponse(200, {
          'items': [
            {'id': testUserId, 'fullName': 'Filter member'},
          ],
          'nextPageToken': null,
        });
      }

      if (request.path.endsWith('/contributions')) {
        calls++;

        return calls == 1
            ? jsonResponse(200, _page(changed: false))
            : response.future;
      }

      throw StateError('Unexpected request: ${request.path}');
    });

    final client = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'))
      ..httpClientAdapter = adapter;

    final builds = <String, int>{};
    final previous = debugOnRebuildDirtyWidget;

    debugOnRebuildDirtyWidget = (element, previouslyBuilt) {
      previous?.call(element, previouslyBuilt);

      final widget = element.widget;

      if (widget is ContributionHistoryTile) {
        builds.update(widget.item.id, (count) => count + 1, ifAbsent: () => 1);
      }
    };

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionCoordinatorProvider.overrideWithValue(session.coordinator),
            apiDioProvider.overrideWithValue(client),
            homeRepositoryProvider.overrideWithValue(MockHomeRepository()),
          ],
          child: MaterialApp(
            theme: RondiTrackTheme.light,
            home: const ContributionHistoryScreen(
              stokvelId: testStokvelId,
              filters: allContributions,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Member 0'), findsOneWidget);
      expect(find.text('Member 1'), findsOneWidget);
      expect(builds['row-0'], greaterThan(0));
      expect(builds['row-1'], greaterThan(0));
      expect(builds.length, lessThan(400));

      builds.clear();

      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();

      await tester.pump();

      expect(find.text('Member 0'), findsOneWidget);
      expect(builds['row-0'] ?? 0, 0);
      expect(builds['row-1'] ?? 0, 0);

      response.complete(jsonResponse(200, _page(changed: true)));

      await refresh;
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(builds['row-0'] ?? 0, 0);
      expect(builds['row-1'], 1);
      expect(builds['row-2'] ?? 0, 0);
      expect(find.text('R\u00A0105,00'), findsOneWidget);

      debugPrint('PERFORMANCE_REBUILDS=${jsonEncode(builds)}');
    } finally {
      debugOnRebuildDirtyWidget = previous;
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
      client.close(force: true);
    }
  });

  testWidgets('rows grow and scroll without clipping at 200% text', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(360, 640);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rows = List.generate(
      3,
      (index) => Contribution(
        id: 'large-$index',
        cycleId: testCycleId,
        cycleNumber: 1,
        userId: testUserId,
        memberName: 'Member $index with a deliberately long family name',
        amount: const Cents(125050),
        status: index == 1
            ? ContributionStatus.unknown
            : ContributionStatus.paid,
        paidAtUtc: testNow,
      ),
    );

    final controller = ContributionHistoryController(
      load: (_, _) async => HistoryPage(rows, null),
    );

    await controller.refresh();

    Widget app(double scale) => MaterialApp(
      theme: RondiTrackTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: ContributionHistoryList(
          controller: controller,
          header: const SizedBox.shrink(),
          onClearFilters: () {},
        ),
      ),
    );

    try {
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();

      final normal = tester.getSize(find.byType(ContributionHistoryTile).first);

      await tester.pumpWidget(app(2));
      await tester.pumpAndSettle();

      final enlarged = tester.getSize(
        find.byType(ContributionHistoryTile).first,
      );

      expect(enlarged.height, greaterThan(normal.height));

      final first = find.byType(ContributionHistoryTile).first;
      final bounds = tester.getRect(first);

      for (final element
          in find
              .descendant(of: first, matching: find.byType(RichText))
              .evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;

        expect(paragraph.didExceedMaxLines, isFalse);

        final rect = paragraph.localToGlobal(Offset.zero) & paragraph.size;

        expect(rect.left, greaterThanOrEqualTo(bounds.left));
        expect(rect.right, lessThanOrEqualTo(bounds.right));
        expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
      }

      await tester.scrollUntilVisible(
        find.text('End of contributions'),
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );

      expect(find.text('End of contributions').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  for (final state in [
    'loading',
    'empty',
    'filtered',
    'firstError',
    'laterError',
  ]) {
    testWidgets('keeps the $state list state', (tester) async {
      var calls = 0;
      final waiting = Completer<HistoryPage>();

      final controller = ContributionHistoryController(
        filters: state == 'filtered'
            ? (cycleId: testCycleId, status: null, memberId: null, days: null)
            : allContributions,
        load: (_, _) async {
          calls++;

          if (state == 'loading') {
            return waiting.future;
          }

          if (state == 'firstError' || (state == 'laterError' && calls > 1)) {
            throw const OfflineFailure(isRead: true);
          }

          return state == 'laterError'
              ? HistoryPage([_contribution()], 'next')
              : const HistoryPage([], null);
        },
      );

      final initial = controller.refresh();

      if (state != 'loading') {
        await initial;
      }

      if (state == 'laterError') {
        await controller.loadMore();
      }

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: RondiTrackTheme.light,
            home: Scaffold(
              body: ContributionHistoryList(
                controller: controller,
                header: const SizedBox.shrink(),
                onClearFilters: () {},
              ),
            ),
          ),
        );

        await tester.pump();

        expect(
          find.text(switch (state) {
            'loading' => 'Loading contributions…',
            'empty' => 'No contributions yet.',
            'filtered' => 'No contributions match these filters.',
            'firstError' => 'Try again',
            _ => 'Try the next page again',
          }),
          findsOneWidget,
        );

        if (state == 'laterError') {
          expect(find.text('Member 0'), findsOneWidget);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    });
  }
}

Map<String, Object?> _page({required bool changed}) => {
  'items': [
    for (var index = 0; index < 400; index++)
      {
        'id': 'row-$index',
        'contributionCycleId': testCycleId,
        'cycleNumber': 1,
        'userId': testUserId,
        'memberName': 'Member $index',
        'amountInCents': changed && index == 1 ? 10500 : 10000,
        'status': 'Paid',
        'paidAtUtc': testNow.toIso8601String(),
      },
  ],
  'nextPageToken': null,
};

Contribution _contribution() => Contribution(
  id: 'row-0',
  cycleId: testCycleId,
  cycleNumber: 1,
  userId: testUserId,
  memberName: 'Member 0',
  amount: const Cents(10000),
  status: ContributionStatus.paid,
  paidAtUtc: testNow,
);
