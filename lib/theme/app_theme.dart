
import 'package:flutter/foundation.dart' show kIsWeb;
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
    // In the browser the default zoom transition redraws both pages at a new
    // scale every frame (no snapshots on the web); a short fade + slide of
    // the new page only is much lighter.
    pageTransitionsTheme: kIsWeb
        ? const PageTransitionsTheme(builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: WebPageTransitionsBuilder(),
            TargetPlatform.iOS: WebPageTransitionsBuilder(),
            TargetPlatform.macOS: WebPageTransitionsBuilder(),
            TargetPlatform.windows: WebPageTransitionsBuilder(),
            TargetPlatform.linux: WebPageTransitionsBuilder(),
            TargetPlatform.fuchsia: WebPageTransitionsBuilder(),
          })
        : null,
    dividerColor: AppColors.line,
    splashFactory: InkRipple.splashFactory,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.s2,
      contentTextStyle: TextStyle(color: AppColors.text, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Web page transition: the new page fades in and slides up a little; the
/// page underneath stays still.
class WebPageTransitionsBuilder extends PageTransitionsBuilder {
  const WebPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

/// Starts downloading the text fonts and waits for them (web only), so the
/// first screens don't switch font in the middle of an animation.
Future<void> preloadFonts() async {
  if (!kIsWeb) return;
  for (final w in <FontWeight>[FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800]) {
    AppText.body(weight: w);
    AppText.display(weight: w);
  }
  try {
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 4));
  } catch (_) {
    // Slow or offline: start anyway with the fallback font.
  }
}
