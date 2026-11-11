import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/app/ronditrack_app.dart';

void main() {
  testWidgets('uses the RondiTrack web colours in both themes', (tester) async {
    await tester.pumpWidget(const RondiTrackApp());

    expect(find.text('RondiTrack'), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final light = app.theme!;
    final dark = app.darkTheme!;

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
}