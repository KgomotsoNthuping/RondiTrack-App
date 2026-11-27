import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_flavor_scope.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/offline/offline_enabled.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/core/theme/ronditrack_theme.dart';
import 'package:ronditrack/core/version/app_version_label.dart';
import 'package:ronditrack/core/version/installed_version.dart';
import 'package:ronditrack/core/version/package_version_source.dart';
import 'package:ronditrack/core/version/version_providers.dart';
import 'package:ronditrack/features/profile/presentation/profile_screen.dart';

import '../support/assignment_12_1_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'adapter reads the installed package version and build number',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'RondiTrack Staging',
        packageName: 'za.co.kgomotsonthuping.ronditrack.staging',
        version: '1.4.0',
        buildNumber: '37',
        buildSignature: '',
      );
      final version = await const PackageVersionSource().read();
      expect(version.version, '1.4.0');
      expect(version.buildNumber, '37');
    },
  );

  for (final flavor in AppFlavor.values) {
    testWidgets('installed version label includes ${flavor.name}', (
      tester,
    ) async {
      final source = _VersionSource();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [versionSourceProvider.overrideWithValue(source)],
          child: MaterialApp(
            theme: RondiTrackTheme.light,
            home: Scaffold(body: AppVersionLabel(flavor: flavor)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Version 2.3.4 (51) · ${flavor.name}'), findsOneWidget);
      expect(source.reads, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('version plugin failure leaves a readable fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          versionSourceProvider.overrideWithValue(_VersionSource(fail: true)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AppVersionLabel(flavor: AppFlavor.dev)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Version unavailable · dev'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile shows the installed version inside the existing theme', (
    tester,
  ) async {
    final session = await TestSession.start();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            useApiRepositoriesProvider.overrideWithValue(true),
            offlineEnabledProvider.overrideWithValue(false),
            sessionCoordinatorProvider.overrideWithValue(session.coordinator),
            versionSourceProvider.overrideWithValue(_VersionSource()),
          ],
          child: AppFlavorScope(
            flavor: AppFlavor.staging,
            child: MaterialApp(
              theme: RondiTrackTheme.light,
              home: const ProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text(testIdentity.email), findsOneWidget);
      expect(find.text('Version 2.3.4 (51) · staging'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    }
  });
}

final class _VersionSource implements VersionSource {
  new({this.fail = false});

  final bool fail;
  int reads = 0;

  @override
  Future<InstalledVersion> read() async {
    reads++;
    if (fail) {
      throw StateError('Package information unavailable');
    }
    return const InstalledVersion(version: '2.3.4', buildNumber: '51');
  }
}
