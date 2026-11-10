import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/app/ronditrack_app.dart';

void main() {
  testWidgets('RondiTrack Mobile App', (tester) async {
    await tester.pumpWidget(const RondiTrackApp());

    expect(find.text('RondiTrack Mobile App'), findsOneWidget);
  });
}