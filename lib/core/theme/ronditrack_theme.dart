import 'package:flutter/material.dart';

/// Light and dark Material themes
abstract final class RondiTrackTheme {
  static const _buttonText = Color(0xFF182014);
  static const _header = Color(0xFF9AE600);
  static const _headerText = Color(0xFF192E03);

  /// The web dashboard's light theme.
  static final ThemeData light = _buildTheme(
    const ColorScheme.light(
      primary: Color(0xFFA3E635),
      onPrimary: _buttonText,
      primaryContainer: Color(0xFFECFCCB),
      onPrimaryContainer: Color(0xFF26351C),
      secondary: Color(0xFFECF5DF),
      onSecondary: Color(0xFF26351C),
      surface: Color(0xFFF7FEE7),
      onSurface: Color(0xFF1A2E05),
      surfaceContainer: Colors.white,
      surfaceContainerHighest: Color(0xFFF1F5E9),
      onSurfaceVariant: Color(0xFF475569),
      outline: Color(0xFFDCE6D4),
      outlineVariant: Color(0xFFDCE6D4),
      error: Color(0xFFB91C1C),
    ),
    cardColor: Colors.white,
    cardBorder: const Color(0xFFE2E8F0),
    focusColor: const Color(0xFF65A30D),
  );

  /// The web dashboard's dark theme.
  static final ThemeData dark = _buildTheme(
    const ColorScheme.dark(
      primary: Color(0xFFBEF264),
      onPrimary: _buttonText,
      primaryContainer: Color(0xFF344829),
      onPrimaryContainer: Color(0xFFF7FEE7),
      secondary: Color(0xFF263624),
      onSecondary: Color(0xFFF7FEE7),
      surface: Color(0xFF101A0C),
      onSurface: Color(0xFFF7FEE7),
      surfaceContainer: Color(0xFF192518),
      surfaceContainerHighest: Color(0xFF263624),
      onSurfaceVariant: Color(0xFFCBD5C2),
      outline: Color(0xFF3B4B37),
      outlineVariant: Color(0xFF3B4B37),
      error: Color(0xFFF87171),
      onError: Color(0xFF101A0C),
    ),
    cardColor: const Color(0xFF0F172B),
    cardBorder: const Color(0xFF314158),
    focusColor: const Color(0xFFBEF264),
  );

  static ThemeData _buildTheme(
    ColorScheme colors, {
    required Color cardColor,
    required Color cardBorder,
    required Color focusColor,
  }) {
    return ThemeData(
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      dividerColor: colors.outline,
      focusColor: focusColor,
      fontFamily: 'Inter',
      appBarTheme: const AppBarThemeData(
        backgroundColor: _header,
        foregroundColor: _headerText,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _headerText,
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: cardBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
    );
  }
}