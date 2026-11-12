import 'package:flutter/material.dart';
import 'package:ronditrack/core/theme/ronditrack_tokens.dart';

abstract final class RondiTrackTheme {
  static const seed = Color(0xFF9AE600);
  static const _buttonText = Color(0xFF182014);
  static const _headerText = Color(0xFF192E03);

  static final ThemeData light = _buildTheme(
    ColorScheme.fromSeed(seedColor: seed).copyWith(
      primary: const Color(0xFFA3E635),
      onPrimary: _buttonText,
      primaryContainer: const Color(0xFFECFCCB),
      onPrimaryContainer: const Color(0xFF26351C),
      secondary: const Color(0xFFECF5DF),
      onSecondary: const Color(0xFF26351C),
      surface: const Color(0xFFF7FEE7),
      onSurface: const Color(0xFF1A2E05),
      surfaceContainer: Colors.white,
      surfaceContainerHighest: const Color(0xFFF1F5E9),
      onSurfaceVariant: const Color(0xFF475569),
      outline: const Color(0xFF45556C),
      outlineVariant: const Color(0xFFE2E8F0),
      error: const Color(0xFFB91C1C),
    ),
    RondiTrackTokens.light,
    focusColor: const Color(0xFF497D00),
  );

  static final ThemeData dark = _buildTheme(
    ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFBEF264),
      onPrimary: _buttonText,
      primaryContainer: const Color(0xFF344829),
      onPrimaryContainer: const Color(0xFFF7FEE7),
      secondary: const Color(0xFF263624),
      onSecondary: const Color(0xFFF7FEE7),
      surface: const Color(0xFF101A0C),
      onSurface: const Color(0xFFF7FEE7),
      surfaceContainer: const Color(0xFF192518),
      surfaceContainerHighest: const Color(0xFF263624),
      onSurfaceVariant: const Color(0xFFCBD5C2),
      outline: const Color(0xFFCAD5E2),
      outlineVariant: const Color(0xFF314158),
      error: const Color(0xFFF87171),
      onError: const Color(0xFF101A0C),
    ),
    RondiTrackTokens.dark,
    focusColor: const Color(0xFFBEF264),
  );

  static ThemeData _buildTheme(
    ColorScheme colors,
    RondiTrackTokens tokens, {
    required Color focusColor,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      extensions: [tokens],
      scaffoldBackgroundColor: colors.surface,
      dividerColor: colors.outlineVariant,
      focusColor: focusColor,
      fontFamily: 'Inter',
      appBarTheme: const AppBarThemeData(
        backgroundColor: seed,
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
        color: tokens[RondiTrackToken.cardText].background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: colors.outlineVariant),
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
      inputDecorationTheme: InputDecorationThemeData(
        floatingLabelStyle: TextStyle(color: colors.onSurfaceVariant),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: focusColor, width: 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: focusColor),
    );
  }
}