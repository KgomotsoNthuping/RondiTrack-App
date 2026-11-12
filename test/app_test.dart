import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/theme/ronditrack_theme.dart';
import 'package:ronditrack/core/theme/ronditrack_tokens.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/data/fake_home_repository.dart';

void main() {
  testWidgets('uses the RondiTrack palette in both system themes', (
    tester,
  ) async {
    final config = AppConfig.parse(
      nativeFlavor: 'dev',
      configuredFlavor: 'dev',
      apiBaseUrl: 'http://10.0.2.2:5227',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
          homeRepositoryProvider.overrideWithValue(
            const FakeHomeRepository(delay: Duration.zero),
          ),
        ],
        child: RondiTrackApp(config: config),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RondiTrack'), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final light = app.theme!;
    final dark = app.darkTheme!;

    expect(app.title, 'RondiTrack Dev');
    expect(app.themeMode, ThemeMode.system);
    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, const Color(0xFFF7FEE7));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF101A0C));
    expect(light.appBarTheme.backgroundColor, const Color(0xFF9AE600));
    expect(dark.appBarTheme.backgroundColor, const Color(0xFF9AE600));
    expect(light.colorScheme.primary, const Color(0xFFA3E635));
    expect(dark.colorScheme.primary, const Color(0xFFBEF264));
    expect(light.colorScheme.onPrimary, const Color(0xFF182014));
    expect(dark.colorScheme.onPrimary, const Color(0xFF182014));
    expect(light.cardTheme.color, Colors.white);
    expect(dark.cardTheme.color, const Color(0xFF0F172B));
  });

  test('keeps token text and input outlines readable in both themes', () {
    for (final theme in [RondiTrackTheme.light, RondiTrackTheme.dark]) {
      final tokens = theme.extension<RondiTrackTokens>()!;
      final card = theme.cardTheme.color!;
      final brightness = theme.brightness.name;

      for (final token in RondiTrackToken.values) {
        final pair = tokens[token];
        final background = Color.alphaBlend(pair.background, card);

        expect(
          _contrast(pair.foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness ${token.name}',
        );
      }

      final muted = tokens[RondiTrackToken.cardMuted].foreground;
      for (final token in [
        RondiTrackToken.paidAmount,
        RondiTrackToken.owedAmount,
      ]) {
        final background = Color.alphaBlend(tokens[token].background, card);

        expect(
          _contrast(muted, background),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness ${token.name} label',
        );
      }

      final input = theme.inputDecorationTheme;
      for (final border in [input.enabledBorder!, input.focusedBorder!]) {
        for (final background in [theme.scaffoldBackgroundColor, card]) {
          expect(
            _contrast(border.borderSide.color, background),
            greaterThanOrEqualTo(3),
            reason: '$brightness input outline',
          );
        }
      }
    }
  });
}

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();

  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}