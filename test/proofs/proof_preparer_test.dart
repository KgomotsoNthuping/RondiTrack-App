import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/features/proofs/data/image_proof_preparer.dart';
import 'package:ronditrack/features/proofs/domain/proof_models.dart';

void main() {
  test('production preparer returns a JPEG through compute', () async {
    final result = await const ImageProofPreparer().prepare(
      img.encodePng(img.Image(width: 8, height: 8)),
      100000,
    );

    expect(img.decodeJpg(result.bytes), isNotNull);
    expect(result.bytes.length, lessThanOrEqualTo(100000));
  });

  test('real GPS metadata is removed and orientation is baked', () {
    final image = img.Image(width: 40, height: 20);

    for (final pixel in image) {
      pixel.setRgb(pixel.y < 10 ? 255 : 0, 0, pixel.y < 10 ? 0 : 255);
    }

    image.exif.imageIfd.orientation = 6;

    final gps = image.exif.gpsIfd;

    gps[1] = img.IfdValueAscii('S');
    gps[2] = _coordinate(29, 7, 0);
    gps[3] = img.IfdValueAscii('E');
    gps[4] = _coordinate(26, 13, 0);

    final original = img.encodeJpg(image, quality: 95);

    final before = img.decodeJpg(original)!;

    expect(before.exif.gpsIfd[2], isNotNull);
    expect(before.exif.gpsIfd[4], isNotNull);

    final result = prepareProofBytes((bytes: original, maxBytes: 100000));

    final after = img.decodeJpg(result.bytes)!;

    expect((after.width, after.height), (20, 40));
    expect(after.exif.isEmpty, isTrue);
    expect(after.exif.gpsIfd.isEmpty, isTrue);
    expect(after.exif.imageIfd.orientation, isNull);

    final left = after.getPixel(2, 20);
    final right = after.getPixel(17, 20);

    expect(left.b, greaterThan(left.r));
    expect(right.r, greaterThan(right.b));

    expect(result.bytes.length, lessThanOrEqualTo(100000));
  });

  test('resizes the longest side without changing the aspect ratio', () {
    final original = img.encodePng(img.Image(width: 2000, height: 1000));

    final result = prepareProofBytes((bytes: original, maxBytes: 1000000));

    expect((result.width, result.height), (1600, 800));
    expect(img.decodeJpg(result.bytes), isNotNull);
  });

  test('transparent PNG output has a white background', () {
    final original = img.encodePng(
      img.Image(width: 10, height: 10, numChannels: 4),
    );

    final result = prepareProofBytes((bytes: original, maxBytes: 100000));

    final pixel = img.decodeJpg(result.bytes)!.getPixel(5, 5);

    expect(pixel.r, greaterThan(240));
    expect(pixel.g, greaterThan(240));
    expect(pixel.b, greaterThan(240));
  });

  test('tries a lower quality when the first JPEG is too large', () {
    final image = img.Image(width: 100, height: 100);

    final random = Random(42);

    for (final pixel in image) {
      pixel.setRgb(
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
      );
    }

    final high = img.encodeJpg(image, quality: 85).length;

    final lower = img.encodeJpg(image, quality: 75).length;

    expect(high, greaterThan(lower));

    final limit = (high + lower) ~/ 2;

    final result = prepareProofBytes((
      bytes: img.encodePng(image),
      maxBytes: limit,
    ));

    expect(result.quality, lessThan(85));
    expect(ProofPolicy.qualities, contains(result.quality));
    expect(result.bytes.length, lessThanOrEqualTo(limit));
  });

  test('fails clearly when no quality fits', () {
    final bytes = img.encodePng(img.Image(width: 10, height: 10));

    expect(
      () => prepareProofBytes((bytes: bytes, maxBytes: 1)),
      throwsA(
        isA<RuleFailure>().having(
          (value) => value.message,
          'message',
          contains('cannot fit'),
        ),
      ),
    );
  });

  test('rejects unsupported input and an unavailable upload limit', () {
    expect(
      () =>
          prepareProofBytes((bytes: Uint8List.fromList([1, 2]), maxBytes: 100)),
      throwsA(isA<RuleFailure>()),
    );

    expect(
      () => prepareProofBytes((bytes: Uint8List(0), maxBytes: 0)),
      throwsA(isA<RuleFailure>()),
    );
  });

  test('rejects payload ids containing paths or queries', () {
    expect(
      ProofTarget.parse(
        stokvelId: '22222222-2222-4222-8222-222222222222',
        cycleId: '33333333-3333-4333-8333-333333333333',
        contributionId: '../profile',
      ),
      isNull,
    );
  });
}

img.IfdValueRational _coordinate(int degrees, int minutes, int seconds) {
  return img.IfdValueRational.list(
    [
      degrees,
      minutes,
      seconds,
    ].map((value) => img.IfdValueRational(value, 1).value.single).toList(),
  );
}
