import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/data/fake_home_repository.dart';

void main() {
  testWidgets('opens each tab at its address', (tester) async {
    final config = AppConfig.parse(
      nativeFlavor: 'dev',
      configuredFlavor: 'dev',
      apiBaseUrl: 'http://10.0.2.2:5227',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeRepositoryProvider.overrideWithValue(
            const FakeHomeRepository(delay: Duration.zero),
          ),
        ],
        child: RondiTrackApp(config: config),
      ),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('RondiTrack')));
    expect(router.routeInformationProvider.value.uri.path, '/');

    for (final (label, path) in const [
      ('Stokvels', '/stokvels'),
      ('Activity', '/activity'),
      ('Profile', '/profile'),
      ('Home', '/'),
    ]) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
    }

    expect(find.text('Family Savers'), findsOneWidget);
    expect(find.text('Work Savers'), findsOneWidget);
  });
}
