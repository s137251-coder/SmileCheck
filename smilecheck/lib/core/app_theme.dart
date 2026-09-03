import 'package:flutter/material.dart';

/// Central design tokens for SmileCheck.
///
/// The product is camera-first, so the palette is dark: a deep slate ground
/// makes the live preview and the verdict colours read clearly, and every
/// surface is built from the same three neutrals plus one accent per state.
class AppColors {
  const AppColors._();

  static const Color background = Color(0xFF070C16);
  static const Color backgroundLift = Color(0xFF0E1626);
  static const Color surface = Color(0xFF121A29);
  static const Color surfaceRaised = Color(0xFF1B2536);
  static const Color border = Color(0x1FFFFFFF);
  static const Color borderStrong = Color(0x33FFFFFF);

  static const Color accent = Color(0xFF3ECF8E);
  static const Color accentDeep = Color(0xFF1E8F62);
  static const Color caution = Color(0xFFF5B44A);
  static const Color danger = Color(0xFFFF5C7A);
  static const Color info = Color(0xFF56A8FF);

  static const Color textPrimary = Color(0xFFF2F6FB);
  static const Color textSecondary = Color(0xFF9AA9BF);
  static const Color textMuted = Color(0xFF6B7A91);

  static const LinearGradient backdrop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B1424), Color(0xFF070C16)],
  );

  static const LinearGradient accentSweep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4FE0A0), Color(0xFF2AA37A)],
  );
}

/// Shared spacing and shape scale, so screens stay visually consistent.
class AppMetrics {
  const AppMetrics._();

  static const double gutter = 22;
  static const double cardRadius = 26;
  static const double pillRadius = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(cardRadius));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(pillRadius));
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: Color(0xFF04231A),
        secondary: AppColors.info,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ).copyWith(
        displaySmall: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: AppColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: AppColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14.5,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
        labelLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppMetrics.card),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: const Color(0xFF04231A),
          minimumSize: const Size.fromHeight(56),
          shape: const RoundedRectangleBorder(borderRadius: AppMetrics.pill),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: AppMetrics.pill),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
