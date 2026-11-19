import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/app/provider_retry.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/theme/ronditrack_theme.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/domain/home_repository.dart';
import 'package:ronditrack/features/home/presentation/home_screen.dart';

void main() {
  const scenarios =
      <({String name, Failure failure, String message, int attempts})>[
        (
          name: 'not found',
          failure: NotFoundFailure(),
          message: 'Not found',
          attempts: 1,
        ),
        (
          name: 'forbidden',
          failure: ForbiddenFailure(detail: 'This action is not permitted.'),
          message: 'This action is not permitted.',
          attempts: 1,
        ),
        (
          name: 'rate limited',
          failure: RateLimitedFailure(retryAfterSeconds: 17),
          message: 'Too many attempts. Try again in 17 seconds.',
          attempts: 1,
        ),
        (
          name: 'server failure',
          failure: ServerFailure(correlationId: 'trace-screen-06'),
          message: 'Sorry, something went wrong on our side.',
          attempts: 1,
        ),
        (
          name: 'offline',
          failure: OfflineFailure(isRead: true),
          message: 'You’re offline, or we couldn’t reach the server.',
          attempts: 3,
        ),
      ];

  for (final scenario in scenarios) {
    testWidgets('Home displays ${scenario.name}', (tester) async {
      final repository = _FailingHomeRepository(scenario.failure);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text(scenario.message), findsOneWidget);
      expect(repository.calls, scenario.attempts);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );

      expect(
        container.read(homeProvider(DemoPersona.lerato.name)).error,
        same(scenario.failure),
      );

      expect(container.read(demoSessionProvider), DemoPersona.lerato);

      if (scenario.failure is OfflineFailure) {
        expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
      } else {
        expect(find.byType(FilledButton), findsNothing);
      }
    });
  }

  testWidgets('server reference stays copyable until dismissed', (
    tester,
  ) async {
    String? copied;

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<Object?, Object?>;
          copied = arguments['text'] as String?;
        }

        return null;
      },
    );

    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final repository = _FailingHomeRepository(
      const ServerFailure(correlationId: 'trace-copy-06'),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Reference: trace-copy-06'), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));

    expect(find.text('Reference: trace-copy-06'), findsOneWidget);

    await tester.tap(find.text('Copy reference'));
    await tester.pump();

    expect(copied, 'trace-copy-06');

    await tester.tap(find.text('Dismiss reference'));
    await tester.pump();

    expect(find.text('Reference: trace-copy-06'), findsNothing);

    expect(
      find.text('Sorry, something went wrong on our side.'),
      findsOneWidget,
    );
  });
}

Widget _app(HomeRepository repository) {
  return ProviderScope(
    retry: appProviderRetry,
    overrides: [
      demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
      homeRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(theme: RondiTrackTheme.light, home: const HomeScreen()),
  );
}

final class _FailingHomeRepository implements HomeRepository {
  new(this.failure);

  final Failure failure;
  int calls = 0;

  @override
  Future<List<HomeEntry>> fetchHome(String userId) async {
    calls++;
    throw failure;
  }
}
