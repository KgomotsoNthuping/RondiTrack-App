import 'dart:convert';

import 'package:ronditrack/core/money/cents.dart';

String randNumber(Cents cents) {
  final absolute = cents.value.abs();
  final whole = absolute ~/ 100;
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  final sign = cents.value < 0 ? '-' : '';
  return '$sign$whole.$fraction';
}

String moneyJson(
  Map<String, Object?> fields,
  Map<String, Cents> amounts,
) {
  final entries = <String>[
    for (final entry in fields.entries)
      '${jsonEncode(entry.key)}:${jsonEncode(entry.value)}',
    for (final entry in amounts.entries)
      '${jsonEncode(entry.key)}:${randNumber(entry.value)}',
  ];
  return '{${entries.join(',')}}';
}

Cents decimalCents(String value) {
  if (value.length > 128) {
    throw const FormatException('The money value is too large.');
  }

  final match = RegExp(
    r'^(-?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$',
  ).firstMatch(value);

  if (match == null) {
    throw const FormatException('Invalid decimal money.');
  }

  final fraction = match[3] ?? '';
  final exponent = int.tryParse(match[4] ?? '0');

  if (exponent == null || exponent.abs() > 128) {
    throw const FormatException('Invalid money exponent.');
  }

  var amount = BigInt.parse('${match[2]}$fraction');
  final shift = 2 + exponent - fraction.length;

  if (shift >= 0) {
    amount *= BigInt.from(10).pow(shift);
  } else {
    final divisor = BigInt.from(10).pow(-shift);

    if (amount.remainder(divisor) != BigInt.zero) {
      throw const FormatException('The value contains fractional cents.');
    }

    amount ~/= divisor;
  }

  if (match[1] == '-') {
    amount = -amount;
  }

  if (amount.abs() > BigInt.from(9_007_199_254_740_991)) {
    throw const FormatException('The money value is too large.');
  }

  return Cents(amount.toInt());
}

Object? decodeMoneyJson(String source) {
  const names = {'targetAmount', 'monthlyContribution'};
  final output = StringBuffer();
  var index = 0;

  while (index < source.length) {
    if (source.codeUnitAt(index) != 34) {
      output.write(source[index++]);
      continue;
    }

    final start = index++;

    while (index < source.length) {
      final character = source.codeUnitAt(index++);

      if (character == 92) {
        index++;
      } else if (character == 34) {
        break;
      }
    }

    if (index > source.length) {
      throw const FormatException('Invalid JSON string.');
    }

    final token = source.substring(start, index);
    output.write(token);

    var colon = index;

    while (colon < source.length && source[colon].trim().isEmpty) {
      colon++;
    }

    if (colon >= source.length ||
        source[colon] != ':' ||
        !names.contains(jsonDecode(token))) {
      continue;
    }

    var valueStart = colon + 1;

    while (valueStart < source.length &&
        source[valueStart].trim().isEmpty) {
      valueStart++;
    }

    output.write(source.substring(index, valueStart));
    index = valueStart;

    while (index < source.length &&
        RegExp(r'[0-9eE+.\-]').hasMatch(source[index])) {
      index++;
    }

    if (index > valueStart) {
      output.write(jsonEncode(source.substring(valueStart, index)));
    }
  }

  return jsonDecode(output.toString());
}