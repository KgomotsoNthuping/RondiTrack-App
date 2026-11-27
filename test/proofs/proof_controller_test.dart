import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/features/proofs/application/proof_upload_controller.dart';
import 'package:ronditrack/features/proofs/domain/proof_models.dart';

import '../support/proof_fakes.dart';

void main() {
  test('cancelled selection is quiet', () async {
    final h = _Harness()..picker.value = null;

    addTearDown(h.controller.dispose);

    await h.controller.choose(ProofSource.gallery);

    expect(h.controller.stage, ProofStage.idle);
    expect(h.controller.failure, isNull);
    expect(h.preparer.calls, 0);
    expect(h.uploader.calls, 0);
  });

  test('picking and upload both reject repeated taps', () async {
    final h = _Harness();

    addTearDown(h.controller.dispose);

    h.picker.wait = Completer();

    final first = h.controller.choose(ProofSource.gallery);

    await h.controller.choose(ProofSource.camera);

    expect(h.picker.calls, 1);

    h.picker.wait!.complete(h.picker.value);
    await first;

    expect(h.controller.stage, ProofStage.ready);

    h.uploader.wait = Completer();

    final upload = h.controller.upload();

    await h.controller.upload();
    await h.controller.choose(ProofSource.gallery);

    expect(h.uploader.calls, 1);
    expect(h.picker.calls, 1);
    expect(h.controller.progress, 0.5);

    h.uploader.wait!.complete(testProofId);

    await upload;

    expect(h.controller.stage, ProofStage.uploaded);
    expect(h.controller.photo, isNull);
    expect(h.controller.proofId, testProofId);
  });

  test('session change discards a late prepared photo', () async {
    final h = _Harness();

    addTearDown(h.controller.dispose);

    h.preparer.wait = Completer();

    final prepare = h.controller.choose(ProofSource.gallery);

    await pumpEventQueue();

    expect(h.controller.stage, ProofStage.preparing);

    h.current = false;
    h.controller.invalidate();

    h.preparer.wait!.complete(preparedTestProof());

    await prepare;

    expect(h.controller.photo, isNull);
    expect(h.controller.stage, ProofStage.idle);
    expect(h.uploader.calls, 0);
  });

  test('session change cancels upload and ignores the late result', () async {
    final h = _Harness();

    addTearDown(h.controller.dispose);

    await h.controller.choose(ProofSource.gallery);

    h.uploader.wait = Completer();

    final upload = h.controller.upload();

    h.current = false;
    h.controller.invalidate();

    expect(h.uploader.cancellations, 1);

    h.uploader.wait!.complete(testProofId);
    await upload;

    expect(h.controller.proofId, isNull);
    expect(h.controller.photo, isNull);
    expect(h.controller.stage, ProofStage.idle);
  });

  test(
    'mapped upload failure keeps the prepared photo for an explicit retry',
    () async {
      final h = _Harness();

      addTearDown(h.controller.dispose);

      await h.controller.choose(ProofSource.gallery);

      h.uploader.failure = const OfflineFailure(isRead: false);

      await h.controller.upload();

      expect(h.controller.stage, ProofStage.failed);
      expect(h.controller.failure, isA<OfflineFailure>());
      expect(h.controller.photo, isNotNull);

      h.uploader.failure = null;

      await h.controller.upload();

      expect(h.uploader.calls, 2);
      expect(h.controller.stage, ProofStage.uploaded);
    },
  );

  test('disabled uploads call no plugin and no network', () async {
    final h = _Harness(
      settings: const ProofSettings(enabled: false, maxBytes: 0),
    );

    addTearDown(h.controller.dispose);

    await h.controller.choose(ProofSource.gallery);
    await h.controller.upload();

    expect(h.picker.calls, 0);
    expect(h.preparer.calls, 0);
    expect(h.uploader.calls, 0);
  });
}

final class _Harness {
  new({ProofSettings settings = testProofSettings}) {
    controller = ProofUploadController(
      target: testProofTarget,
      settings: settings,
      picker: picker,
      preparer: preparer,
      uploader: uploader,
      isCurrent: () => current,
    );
  }

  final picker = TestProofPicker();
  final preparer = TestProofPreparer();
  final uploader = TestProofUploader();

  bool current = true;

  late final ProofUploadController controller;
}
