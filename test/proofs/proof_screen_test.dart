import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/core/theme/ronditrack_theme.dart';
import 'package:ronditrack/features/proofs/application/proof_providers.dart';
import 'package:ronditrack/features/proofs/application/proof_upload_controller.dart';
import 'package:ronditrack/features/proofs/domain/proof_models.dart';
import 'package:ronditrack/features/proofs/presentation/proof_upload_screen.dart';

import '../support/assignment_12_1_fixtures.dart';
import '../support/proof_fakes.dart';

void main() {
  for (final enabled in [true, false]) {
    testWidgets('proof screen upload controls: enabled=$enabled', (
      tester,
    ) async {
      final session = await TestSession.start();

      final settings = enabled
          ? testProofSettings
          : const ProofSettings(enabled: false, maxBytes: 0);

      final picker = TestProofPicker();

      final uploader = TestProofUploader()..wait = Completer<String>();

      final controller = ProofUploadController(
        target: testProofTarget,
        settings: settings,
        picker: picker,
        preparer: TestProofPreparer(),
        uploader: uploader,
        isCurrent: () => true,
      );

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionCoordinatorProvider.overrideWithValue(session.coordinator),
              proofSettingsProvider.overrideWithValue(settings),
              proofCameraAvailableProvider.overrideWithValue(true),
              proofControllerProvider.overrideWith((_, _) => controller),
            ],
            child: MaterialApp(
              theme: RondiTrackTheme.light,
              home: ProofUploadScreen(target: testProofTarget),
            ),
          ),
        );

        final gallery = find.byKey(const ValueKey('proof-gallery'));

        final upload = find.byKey(const ValueKey('proof-upload'));

        if (!enabled) {
          expect(tester.widget<OutlinedButton>(gallery).onPressed, isNull);
          expect(tester.widget<FilledButton>(upload).onPressed, isNull);
          expect(
            find.text('Proof uploads are not available on this build.'),
            findsOneWidget,
          );
          expect(picker.calls, 0);
          expect(tester.takeException(), isNull);
          return;
        }

        await tester.tap(gallery);
        await tester.pumpAndSettle();

        expect(find.text('Photo ready to upload.'), findsOneWidget);
        expect(find.byKey(const ValueKey('proof-preview')), findsOneWidget);

        await tester.ensureVisible(upload);
        await tester.tap(upload);
        await tester.pump();

        expect(tester.widget<FilledButton>(upload).onPressed, isNull);
        expect(tester.widget<OutlinedButton>(gallery).onPressed, isNull);
        expect(find.text('Uploading proof…'), findsWidgets);
        expect(uploader.calls, 1);

        uploader.wait!.complete(testProofId);

        await tester.pumpAndSettle();

        expect(find.text('Proof uploaded.'), findsOneWidget);
        expect(find.byKey(const ValueKey('proof-preview')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());

        controller.dispose();
        session.dispose();
      }
    });
  }
}
