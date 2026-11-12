import 'package:flutter/material.dart';

typedef RondiTrackColorPair = ({Color foreground, Color background});

enum RondiTrackToken {
  cardText,
  cardMuted,
  wallet,
  paidAmount,
  owedAmount,
  paidUp,
  arrears,
  open,
  closed,
  paidOut,
  unknown,
  pending,
  paid,
}

final class RondiTrackTokens extends ThemeExtension<RondiTrackTokens> {
  const new _(this._colors);

  final Map<RondiTrackToken, RondiTrackColorPair> _colors;

  static const _slate950 = Color(0xFF020618);
  static const _slate900 = Color(0xFF0F172B);
  static const _slate700 = Color(0xFF314158);
  static const _lime950 = Color(0xFF192E03);
  static const _lime900 = Color(0xFF35530E);
  static const _lime300 = Color(0xFFBBF451);

  static const light = RondiTrackTokens._({
    RondiTrackToken.cardText: (
      foreground: _slate950,
      background: Colors.white,
    ),
    RondiTrackToken.cardMuted: (
      foreground: Color(0xFF45556C),
      background: Colors.white,
    ),
    RondiTrackToken.wallet: (
      foreground: _lime900,
      background: Color(0xFFECFCCA),
    ),
    RondiTrackToken.paidAmount: (
      foreground: _lime900,
      background: Color(0xFFF7FEE7),
    ),
    RondiTrackToken.owedAmount: (
      foreground: _slate950,
      background: Color(0xFFF8FAFC),
    ),
    RondiTrackToken.paidUp: (
      foreground: _lime950,
      background: Color(0xFFECFCCA),
    ),
    RondiTrackToken.arrears: (
      foreground: Color(0xFF460809),
      background: Color(0xFFFFE2E2),
    ),
    RondiTrackToken.open: (
      foreground: _lime950,
      background: Color(0xFFD8F999),
    ),
    RondiTrackToken.closed: (
      foreground: _slate900,
      background: Color(0xFFE2E8F0),
    ),
    RondiTrackToken.paidOut: (
      foreground: Color(0xFF162456),
      background: Color(0xFFDBEAFE),
    ),
    RondiTrackToken.unknown: (
      foreground: _slate900,
      background: Color(0xFFF1F5F9),
    ),
    RondiTrackToken.pending: (
      foreground: Color(0xFF461901),
      background: Color(0xFFFEF3C6),
    ),
    RondiTrackToken.paid: (
      foreground: Color(0xFF052F4A),
      background: Color(0xFFDFF2FE),
    ),
  });

  static const dark = RondiTrackTokens._({
    RondiTrackToken.cardText: (
      foreground: Colors.white,
      background: _slate900,
    ),
    RondiTrackToken.cardMuted: (
      foreground: Color(0xFFCAD5E2),
      background: _slate900,
    ),
    RondiTrackToken.wallet: (
      foreground: _lime950,
      background: _lime300,
    ),
    RondiTrackToken.paidAmount: (
      foreground: Color(0xFFD8F999),
      background: Color(0x66192E03),
    ),
    RondiTrackToken.owedAmount: (
      foreground: Colors.white,
      background: Color(0xFF1D293D),
    ),
    RondiTrackToken.paidUp: (
      foreground: _lime950,
      background: _lime300,
    ),
    RondiTrackToken.arrears: (
      foreground: Color(0xFF460809),
      background: Color(0xFFFFA2A2),
    ),
    RondiTrackToken.open: (
      foreground: _lime950,
      background: _lime300,
    ),
    RondiTrackToken.closed: (
      foreground: Colors.white,
      background: _slate700,
    ),
    RondiTrackToken.paidOut: (
      foreground: Color(0xFF162456),
      background: Color(0xFF8EC5FF),
    ),
    RondiTrackToken.unknown: (
      foreground: Colors.white,
      background: _slate700,
    ),
    RondiTrackToken.pending: (
      foreground: Color(0xFF461901),
      background: Color(0xFFFFD230),
    ),
    RondiTrackToken.paid: (
      foreground: Color(0xFF052F4A),
      background: Color(0xFF74D4FF),
    ),
  });

  static RondiTrackTokens of(BuildContext context) {
    return Theme.of(context).extension<RondiTrackTokens>()!;
  }

  RondiTrackColorPair operator [](RondiTrackToken token) => _colors[token]!;

  @override
  RondiTrackTokens copyWith({
    Map<RondiTrackToken, RondiTrackColorPair>? colors,
  }) {
    if (colors == null) {
      return this;
    }

    return RondiTrackTokens._(Map.unmodifiable({..._colors, ...colors}));
  }

  @override
  RondiTrackTokens lerp(covariant RondiTrackTokens? other, double t) {
    if (other == null) {
      return this;
    }

    return RondiTrackTokens._(
      Map.unmodifiable({
        for (final token in RondiTrackToken.values)
          token: (
            foreground: Color.lerp(
              this[token].foreground,
              other[token].foreground,
              t,
            )!,
            background: Color.lerp(
              this[token].background,
              other[token].background,
              t,
            )!,
          ),
      }),
    );
  }
}