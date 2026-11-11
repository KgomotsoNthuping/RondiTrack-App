import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/money/cents.dart';

void main() {
  group('Cents.formatRand', () {
    const examples = {
      0: 'R\u00A00,00',
      10: 'R\u00A00,10',
      15_050: 'R\u00A0150,50',
      150_000: 'R\u00A01\u00A0500,00',
      100_000_000: 'R\u00A01\u00A0000\u00A0000,00',
      -150: '-R\u00A01,50',
      -10: '-R\u00A00,10',
      9_007_199_254_740_991: 'R\u00A090\u00A0071\u00A0992\u00A0547\u00A0409,91',
    };

    for (final example in examples.entries) {
      test('formats ${example.key} cents', () {
        expect(Cents(example.key).formatRand(), example.value);
      });
    }

    test('rejects cents above the supported range', () {
      expect(
        () => const Cents(9_007_199_254_740_992).formatRand(),
        throwsRangeError,
      );
    });
  });

  group('parseRand', () {
    const accepted = {
      '0': 0,
      '150': 15_000,
      '150,50': 15_050,
      'R150': 15_000,
      'R 1 500': 150_000,
      '1 500,50': 150_050,
      '1\u00A0500,50': 150_050,
      'R\u00A01\u00A0500,50': 150_050,
      '150.50': 15_050,
      '150.5': 15_050,
      '150,5': 15_050,
      '90071992547409,91': 9_007_199_254_740_991,
    };

    for (final example in accepted.entries) {
      test('accepts "${example.key}"', () {
        expect(
          parseRand(example.key),
          isA<ParsedRand>().having(
            (result) => result.cents.value,
            'cents',
            example.value,
          ),
        );
      });
    }

    const rejected = [
      '1,500.50',
      '150,505',
      '150.',
      '150,',
      'letters',
      '-150',
      '1 50,00',
      '1  500,00',
    ];

    for (final input in rejected) {
      test('rejects "$input" with a reason', () {
        expect(
          parseRand(input),
          isA<InvalidRand>().having(
            (result) => result.reason,
            'reason',
            isNotEmpty,
          ),
        );
      });
    }

    test('rejects empty input with a reason', () {
      expect(
        parseRand(''),
        isA<InvalidRand>().having(
          (result) => result.reason,
          'reason',
          'Enter an amount.',
        ),
      );
    });

    test('rejects an amount one cent above the supported range', () {
      expect(
        parseRand('90071992547409,92'),
        isA<InvalidRand>().having(
          (result) => result.reason,
          'reason',
          'The amount is too large.',
        ),
      );
    });
  });
}
