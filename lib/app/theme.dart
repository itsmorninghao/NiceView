import 'package:flutter/material.dart';

const niceBlack = Color(0xFF101113);
const niceText = Color(0xFFF4F0EA);
const niceMuted = Color(0xFFA7A19A);
const niceAmber = Color(0xFFD9A441);
const niceDanger = Color(0xFFE46D5B);

ThemeData buildNiceViewTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    colorScheme: const ColorScheme.dark(
      surface: niceBlack,
      onSurface: niceText,
      primary: niceAmber,
      secondary: niceMuted,
      error: niceDanger,
    ),
    scaffoldBackgroundColor: niceBlack,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black.withValues(alpha: 0.82),
      contentTextStyle: const TextStyle(color: niceText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      selectedColor: niceAmber.withValues(alpha: 0.22),
      labelStyle: const TextStyle(color: niceText),
      secondaryLabelStyle: const TextStyle(color: niceText),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
