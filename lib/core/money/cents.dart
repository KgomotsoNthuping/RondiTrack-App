const _noBreakSpace = '\u00A0';
const _maxSafeCents = 9_007_199_254_740_991;
final _maxSafeCentsAsBigInt = BigInt.from(_maxSafeCents);

final _randPattern = RegExp(
  r'^(?:[Rr][ \u00A0]*)?'
  r'([0-9]+|[0-9]{1,3}(?:[ \u00A0][0-9]{3})+)'
  r'(?:[.,]([0-9]{1,2}))?$',
);
final _groupSpaces = RegExp(r'[ \u00A0]');

/// An amount stored as a signed integer number of cents.
extension type const Cents(int value) {
  /// Formats this amount as South African rands.
  String formatRand() {
    if (value < -_maxSafeCents || value > _maxSafeCents) {
      throw RangeError.range(value, -_maxSafeCents, _maxSafeCents, 'cents');
    }

    final absoluteCents = value.abs();
    final wholeDigits = (absoluteCents ~/ 100).toString();
    final fraction = (absoluteCents % 100).toString().padLeft(2, '0');
    final groupedRands = StringBuffer();

    for (var index = 0; index < wholeDigits.length; index++) {
      if (index > 0 && (wholeDigits.length - index) % 3 == 0) {
        groupedRands.write(_noBreakSpace);
      }
      groupedRands.write(wholeDigits[index]);
    }

    final sign = value < 0 ? '-' : '';
    return '${sign}R$_noBreakSpace$groupedRands,$fraction';
  }
}

/// The result of parsing a typed rand amount.
sealed class RandParseResult {
  const new _();
}

/// A successfully parsed amount.
final class ParsedRand extends RandParseResult {
  /// Creates a successful result.
  const new(this.cents) : super._();

  /// The exact amount in cents.
  final Cents cents;
}

/// An amount that could not be parsed.
final class InvalidRand extends RandParseResult {
  /// Creates a failure with a message for the payment form.
  const new(this.reason) : super._();

  /// The reason the amount was rejected.
  final String reason;
}

/// Parses a non-negative rand amount for the payment form.
RandParseResult parseRand(String text) {
  final input = text.trim();
  if (input.isEmpty) {
    return const InvalidRand('Enter an amount.');
  }

  final match = _randPattern.firstMatch(input);
  if (match == null) {
    return const InvalidRand(
      'Enter a rand amount with up to two decimal places, such as 150,50.',
    );
  }

  final wholeDigits = match[1]!.replaceAll(_groupSpaces, '');
  final fraction = (match[2] ?? '').padRight(2, '0');
  final cents = BigInt.parse('$wholeDigits$fraction');

  if (cents > _maxSafeCentsAsBigInt) {
    return const InvalidRand('The amount is too large.');
  }

  return ParsedRand(Cents(cents.toInt()));
}
