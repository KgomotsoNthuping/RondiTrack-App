import 'dart:async';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/features/proofs/domain/proof_models.dart';

const testContributionId = '55555555-5555-4555-8555-555555555555';

const testProofId = '66666666-6666-4666-8666-666666666666';

const testProofSettings = ProofSettings(enabled: true, maxBytes: 100000);

final testProofTarget = ProofTarget.parse(
  stokvelId: '22222222-2222-4222-8222-222222222222',
  cycleId: '33333333-3333-4333-8333-333333333333',
  contributionId: testContributionId,
)!;

PreparedProof preparedTestProof() => PreparedProof(
  bytes: img.encodeJpg(img.Image(width: 8, height: 8)),
  width: 8,
  height: 8,
  quality: 85,
);

final class TestProofPicker implements ProofPicker {
  int calls = 0;

  Uint8List? value = Uint8List.fromList([1, 2, 3]);
  Completer<Uint8List?>? wait;

  @override
  Future<Uint8List?> pick(ProofSource source) async {
    calls++;

    return wait == null ? value : await wait!.future;
  }
}

final class TestProofPreparer implements ProofPreparer {
  int calls = 0;

  Completer<PreparedProof>? wait;

  @override
  Future<PreparedProof> prepare(Uint8List bytes, int maxBytes) async {
    calls++;

    return wait == null ? preparedTestProof() : await wait!.future;
  }
}

final class TestProofUploader implements ProofUploader {
  int calls = 0;
  int cancellations = 0;

  Failure? failure;
  Completer<String>? wait;

  @override
  Future<String> upload(
    ProofTarget target,
    PreparedProof photo, {
    required void Function(int sent, int total) onProgress,
  }) async {
    calls++;
    onProgress(1, 2);

    if (failure case final error?) {
      throw error;
    }

    return wait == null ? testProofId : await wait!.future;
  }

  @override
  void cancel() => cancellations++;
}
