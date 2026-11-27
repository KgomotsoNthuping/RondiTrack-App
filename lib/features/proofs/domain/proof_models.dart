import 'dart:typed_data';

enum ProofSource { camera, gallery }

abstract final class ProofPolicy {
  static const maxSourceBytes = 20 * 1024 * 1024;
  static const maxPixels = 64000000;
  static const maxSide = 1600;
  static const qualities = [85, 75, 65, 55, 45];
}

final class ProofSettings {
  const new({required this.enabled, required this.maxBytes});

  factory fromEnvironment() {
    const requested = bool.fromEnvironment('PROOF_UPLOAD_ENABLED');
    const maximum = int.fromEnvironment('PROOF_MAX_BYTES');

    return const ProofSettings(
      enabled: requested && maximum > 0,
      maxBytes: maximum > 0 ? maximum : 0,
    );
  }

  final bool enabled;
  final int maxBytes;
}

final class ProofTarget {
  const new _(this.stokvelId, this.cycleId, this.contributionId);

  final String stokvelId;
  final String cycleId;
  final String contributionId;

  static bool validId(String value) =>
      value.length == 36 &&
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-'
        r'[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(value);

  static ProofTarget? parse({
    required String stokvelId,
    required String cycleId,
    required String contributionId,
  }) {
    if (![stokvelId, cycleId, contributionId].every(validId)) {
      return null;
    }

    return ProofTarget._(
      stokvelId.toLowerCase(),
      cycleId.toLowerCase(),
      contributionId.toLowerCase(),
    );
  }

  String get cycleLocation => '/stokvels/$stokvelId/cycles/$cycleId';

  String get uploadPath =>
      '/api/v1/stokvels/$stokvelId/cycles/'
      '$cycleId/contributions/$contributionId/proof';
}

final class PreparedProof {
  const new({
    required this.bytes,
    required this.width,
    required this.height,
    required this.quality,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int quality;
}

abstract interface class ProofPicker {
  Future<Uint8List?> pick(ProofSource source);
}

abstract interface class ProofPreparer {
  Future<PreparedProof> prepare(Uint8List bytes, int maxBytes);
}

abstract interface class ProofUploader {
  Future<String> upload(
    ProofTarget target,
    PreparedProof photo, {
    required void Function(int sent, int total) onProgress,
  });

  void cancel();
}
