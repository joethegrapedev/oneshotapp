import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The hand-drawn "paper & ink" aesthetic.
///
/// One warm off-white paper, one near-black ink, one muted terracotta accent.
/// Generous negative space, rounded organic shapes, minimal chrome. Headings use
/// a softly-rounded serif (Fraunces); body/writing uses a humanist sans
/// (Nunito Sans) with a high line-height on the writing surface.
class AppColors {
  const AppColors._();

  static const Color paper = Color(0xFFFBF7F0);
  static const Color paperShade = Color(0xFFF3ECE0);
  static const Color ink = Color(0xFF1E1B18);
  static const Color inkSoft = Color(0xFF6B655E);
  static const Color accent = Color(0xFFC05C3A);
  static const Color accentSoft = Color(0xFFE9C7B8);
  static const Color danger = Color(0xFF9B3B2E);
  static const Color line = Color(0xFF2A2622);
}

class AppRadius {
  const AppRadius._();
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
}

class AppSpace {
  const AppSpace._();
  static const double xs = 6;
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 36;
}

class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(TextTheme base) {
    final serif = GoogleFonts.fraunces(color: AppColors.ink);
    final sans = GoogleFonts.nunitoSans(color: AppColors.ink);

    return base.copyWith(
      displaySmall: serif.copyWith(fontSize: 32, fontWeight: FontWeight.w600),
      headlineMedium:
          serif.copyWith(fontSize: 26, fontWeight: FontWeight.w600),
      headlineSmall: serif.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      titleLarge: serif.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: sans.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
      bodyLarge: sans.copyWith(fontSize: 17, height: 1.6),
      bodyMedium: sans.copyWith(fontSize: 15, height: 1.5),
      bodySmall: sans.copyWith(
        fontSize: 13,
        height: 1.4,
        color: AppColors.inkSoft,
      ),
      labelLarge: sans.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  /// Style for the writing surface itself — roomy and calm.
  static TextStyle writing() => GoogleFonts.nunitoSans(
        color: AppColors.ink,
        fontSize: 18,
        height: 1.7,
      );
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.ink,
        onPrimary: AppColors.paper,
        secondary: AppColors.accent,
        onSecondary: AppColors.paper,
        surface: AppColors.paper,
        onSurface: AppColors.ink,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.paper,
    );

    return base.copyWith(
      textTheme: AppTypography.textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.accentSoft,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.nunitoSans(color: AppColors.paper),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.inkSoft),
      ),
    );
  }
}
