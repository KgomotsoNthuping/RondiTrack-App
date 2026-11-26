import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/features/proofs/domain/proof_models.dart';

final class ImageProofPreparer implements ProofPreparer {
  const ImageProofPreparer();

  @override
  Future<PreparedProof> prepare(Uint8List bytes, int maxBytes) {
    return compute(prepareProofBytes, (bytes: bytes, maxBytes: maxBytes));
  }
}

PreparedProof prepareProofBytes(({Uint8List bytes, int maxBytes}) request) {
  if (request.maxBytes <= 0) {
    throw const RuleFailure(detail: 'Proof uploads are unavailable.');
  }

  if (request.bytes.isEmpty ||
      request.bytes.length > ProofPolicy.maxSourceBytes) {
    throw const RuleFailure(detail: 'Choose a photo smaller than 20 MB.');
  }

  try {
    final jpeg = img.JpegDecoder(maxPixels: ProofPolicy.maxPixels);

    final png = img.PngDecoder(maxPixels: ProofPolicy.maxPixels);

    final img.Decoder? decoder = jpeg.isValidFile(request.bytes)
        ? jpeg
        : png.isValidFile(request.bytes)
        ? png
        : null;

    final decoded = decoder?.decode(request.bytes, frame: 0);

    if (decoded == null) {
      throw const RuleFailure(detail: 'Choose a readable JPEG or PNG photo.');
    }

    var image = img.bakeOrientation(decoded);

    if (image.width > ProofPolicy.maxSide ||
        image.height > ProofPolicy.maxSide) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? ProofPolicy.maxSide : null,
        height: image.height > image.width ? ProofPolicy.maxSide : null,
        interpolation: img.Interpolation.average,
      );
    }

    image = image.convert(numChannels: image.hasAlpha ? 4 : 3);

    image.exif = img.ExifData();
    image.iccProfile = null;
    image.textData = null;

    if (image.hasAlpha) {
      final background = img.Image(
        width: image.width,
        height: image.height,
        numChannels: 3,
      );

      img.fill(background, color: img.ColorRgb8(255, 255, 255));

      img.compositeImage(background, image);
      image = background;
    }

    for (final quality in ProofPolicy.qualities) {
      final bytes = img.encodeJpg(image, quality: quality);

      if (bytes.length <= request.maxBytes) {
        return PreparedProof(
          bytes: bytes,
          width: image.width,
          height: image.height,
          quality: quality,
        );
      }
    }

    throw const RuleFailure(
      detail:
          'This photo cannot fit the upload limit. '
          'Crop it or choose a smaller photo.',
    );
  } on Failure {
    rethrow;
  } on Object {
    throw const RuleFailure(
      detail:
          'Could not prepare this photo. '
          'Choose a different JPEG or PNG.',
    );
  }
}
