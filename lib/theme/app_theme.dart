import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MAMOA brand colors & design system.
///
/// Brand palette (from the design sheet):
/// Blush Pink #FCB5CE, Mauve #B68A73, Cream #FFF7F2, Sage #E7EFE6, Warm Gray #968F8F
class AppColors {
  AppColors._();

  // Brand core
  static const Color blushPink = Color(0xFFFCB5CE);
  static const Color blushPinkDeep = Color(0xFFF49BB8);
  static const Color mauve = Color(0xFFB68A73);
  static const Color cream = Color(0xFFFFF7F2);
  static const Color sage = Color(0xFFE7EFE6);
  static const Color sageDeep = Color(0xFFB7D0B5);
  static const Color warmGray = Color(0xFF968F8F);

  // Accent supports
  static const Color lavender = Color(0xFFC9BEE6);
  static const Color lavenderSoft = Color(0xFFEDE7F6);
  static const Color softYellow = Color(0xFFF6E2A8);
  static const Color peach = Color(0xFFF8D7C4);

  // Surfaces
  static const Color surface = Color(0xFFFFFDFB);
  static const Color cardPink = Color(0xFFFDEEF2);
  static const Color cardCream = Color(0xFFFFF4EC);
  static const Color cardSage = Color(0xFFEEF4ED);
  static const Color cardLavender = Color(0xFFF1ECF8);

  // Text
  static const Color textDark = Color(0xFF5C5350);
  static const Color textBody = Color(0xFF7A716D);
  static const Color textMuted = Color(0xFFA89F9B);

  // Lines
  static const Color line = Color(0xFFF0E6E1);
}

class AppRadius {
  AppRadius._();
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 30;
}

class AppShadows {
  AppShadows._();
  static List<BoxShadow> soft = [
    BoxShadow(
      color: const Color(0xFFE9B9C6).withValues(alpha: 0.18),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFFD9C5BD).withValues(alpha: 0.14),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.zenMaruGothicTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.blushPink,
        secondary: AppColors.mauve,
        surface: AppColors.surface,
        onPrimary: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        titleTextStyle: GoogleFonts.zenMaruGothic(
          color: AppColors.textDark,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dividerColor: AppColors.line,
      splashColor: AppColors.blushPink.withValues(alpha: 0.12),
      highlightColor: AppColors.blushPink.withValues(alpha: 0.06),
    );
  }
}
