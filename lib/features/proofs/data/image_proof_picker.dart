import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/features/proofs/domain/proof_models.dart';

final class ImageProofPicker implements ProofPicker {
  final _picker = ImagePicker();

  @override
  Future<Uint8List?> pick(ProofSource source) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _picker.retrieveLostData();
      }

      final file = await _picker.pickImage(
        source: source == ProofSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        requestFullMetadata: false,
      );

      if (file == null) {
        return null;
      }

      if (await file.length() > ProofPolicy.maxSourceBytes) {
        throw const RuleFailure(
          detail:
              'This photo is too large to prepare. '
              'Choose a smaller photo.',
        );
      }

      return await file.readAsBytes();
    } on PlatformException {
      throw const RuleFailure(
        detail:
            'Could not open the camera or photos. '
            'Check access in Settings.',
      );
    } on Failure {
      rethrow;
    } on Object {
      throw const RuleFailure(
        detail:
            'Could not read this photo. '
            'Please choose it again.',
      );
    }
  }
}
