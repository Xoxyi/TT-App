import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors: black, orange-red and white.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF0A0A0A); // near-black background
  static const Color s1 = Color(0xFF151515); // cards
  static const Color s2 = Color(0xFF222222); // tracks, chips
  static const Color line = Color(0xFF2C2C2C); // borders
  static const Color text = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFA6A6A6);
  static const Color accent = Color(0xFFFF5A1F); // orange-red
  static const Color accentText = Color(0xFFFF7B4D); // orange-red for text on black
  static const Color accentSoft = Color(0x2EFF5A1F); // 18% orange-red
  static const Color onAccent = Color(0xFF0A0A0A); // text/icons on orange-red
  static const Color lossBar = Color(0xFF3D3D3D);
}

/// Text styles: Manrope for UI and numbers, Bricolage Grotesque for headings.
class AppText {
  AppText._();

  static final List<FontFeature> _tabular = <FontFeature>[
    const FontFeature.tabularFigures(),
  ];

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.text,
    double? height,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      fontFeatures: _tabular,
    );
  }

  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.text,
  }) {
    try {
      return GoogleFonts.getFont(
        'Bricolage Grotesque',
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: -0.02 * size,
        height: 1.1,
      );
    } catch (_) {
      // Fallback if the font isn't available in this google_fonts version.
      return GoogleFonts.manrope(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.02 * size,
        height: 1.1,
      );
    }
  }
}

ThemeData buildDarkTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      surface: AppColors.s1,
      onSurface: AppColors.text,
      error: Color(0xFFFF8A80),
    ),
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    dividerColor: AppColors.line,
    splashFactory: InkRipple.splashFactory,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.s2,
      contentTextStyle: TextStyle(color: AppColors.text, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
