import 'package:flutter/material.dart';

/// Melody Bubbly Design System
///
/// Colors, shadows, and typography matching the React reference implementation.
/// Primary: Terracotta #E67E5F
/// Secondary: Dark Navy #1A2E35
/// Accent: Mustard #F4C430
/// Background: Cream #F9F3EA
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFFE67E5F);
  static const Color primaryLight = Color(0xFFF2A88C);
  static const Color primaryDark = Color(0xFFD45A3A);

  // Secondary Colors
  static const Color secondary = Color(0xFF1A2E35);
  static const Color secondaryLight = Color(0xFF2A4A52);

  // Accent Colors
  static const Color accent = Color(0xFFF4C430);

  // Background Colors
  static const Color background = Color(0xFFF9F3EA);
  static const Color backgroundDark = Color(0xFF0A0A0B);

  // Card Colors
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E1E1E);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A2E35);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFFFFFFFF);

  // Category Colors
  static const Color categoryTouching = Color(0xFFE67E5F); // Primary
  static const Color categoryListening = Color(0xFFF4C430); // Accent
  static const Color categorySpeaking = Color(0xFF60A5FA); // Blue
  static const Color categoryVisual = Color(0xFF22C55E); // Green
  static const Color categoryFocus = Color(0xFFA855F7); // Purple

  // Track Background Colors
  static const Color trackBg1 = Color(0xFFF2E8D5);
  static const Color trackBg2 = Color(0xFFE5EDF0);
  static const Color trackBg3 = Color(0xFFFDE4E4);
  static const Color trackBg4 = Color(0xFFE9F4F0);

  // Utility Colors
  static const Color divider = Color(0xFFE2E8F0);
  static const Color shadow = Color(0x1A000000);
  static const Color transparent = Colors.transparent;
}

/// Bubbly shadow system for that soft, rounded aesthetic
class AppShadows {
  /// Standard bubbly shadow - soft and diffuse
  static List<BoxShadow> get bubbly => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.05),
      blurRadius: 25,
      spreadRadius: -5,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.05),
      blurRadius: 10,
      spreadRadius: -6,
      offset: const Offset(0, 8),
    ),
  ];

  /// Elevated shadow for interactive elements
  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.30),
      blurRadius: 15,
      spreadRadius: 0,
      offset: const Offset(0, 6),
    ),
  ];

  /// Card shadow for content cards
  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.04),
      blurRadius: 20,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    ),
  ];

  /// Bottom navigation shadow
  static List<BoxShadow> get navigation => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.08),
      blurRadius: 20,
      spreadRadius: -5,
      offset: const Offset(0, 4),
    ),
  ];

  /// Mini player shadow
  static List<BoxShadow> get miniPlayer => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.12),
      blurRadius: 8,
      offset: const Offset(0, -2),
    ),
  ];
}

/// Rounded corner system for bubbly aesthetic
class AppRadius {
  /// Small radius - 12px
  static const double sm = 12.0;

  /// Medium radius - 16px
  static const double md = 16.0;

  /// Default radius - 24px
  static const double lg = 24.0;

  /// Extra large - 32px
  static const double xl = 32.0;

  /// 2x large - 40px
  static const double xxl = 40.0;

  /// 3x large - 48px
  static const double xxxl = 48.0;

  /// Full circle
  static const double full = 999.0;

  // BorderRadius helpers
  static BorderRadius get small => BorderRadius.circular(sm);
  static BorderRadius get medium => BorderRadius.circular(md);
  static BorderRadius get large => BorderRadius.circular(lg);
  static BorderRadius get xLarge => BorderRadius.circular(xl);
  static BorderRadius get xxLarge => BorderRadius.circular(xxl);
  static BorderRadius get xxxLarge => BorderRadius.circular(xxxl);
  static BorderRadius get circular => BorderRadius.circular(full);
}

/// Typography system using Plus Jakarta Sans
class AppTypography {
  static const String fontFamily = 'Plus Jakarta Sans';

  // Font Weights
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extrabold = FontWeight.w800;

  // Text Styles
  static TextStyle get displayLarge => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: extrabold,
    fontSize: 32,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static TextStyle get displayMedium => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: bold,
    fontSize: 28,
    height: 1.2,
    letterSpacing: -0.3,
  );

  static TextStyle get heading1 => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: bold,
    fontSize: 24,
    height: 1.3,
  );

  static TextStyle get heading2 => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: bold,
    fontSize: 20,
    height: 1.3,
  );

  static TextStyle get heading3 => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: semibold,
    fontSize: 18,
    height: 1.4,
  );

  static TextStyle get bodyLarge => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: regular,
    fontSize: 16,
    height: 1.5,
  );

  static TextStyle get bodyMedium => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: regular,
    fontSize: 14,
    height: 1.5,
  );

  static TextStyle get bodySmall => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: regular,
    fontSize: 12,
    height: 1.4,
  );

  static TextStyle get labelLarge => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: medium,
    fontSize: 14,
    height: 1.4,
  );

  static TextStyle get labelMedium => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: semibold,
    fontSize: 12,
    height: 1.3,
  );

  static TextStyle get labelSmall => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: bold,
    fontSize: 10,
    height: 1.2,
    letterSpacing: 0.5,
  );

  static TextStyle get button => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: semibold,
    fontSize: 14,
    height: 1.4,
  );
}

/// Main application theme configuration
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.background,
        surfaceContainerHighest: AppColors.card,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTypography.fontFamily,
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(
          color: AppColors.textPrimary,
        ),
        displayMedium: AppTypography.displayMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        headlineLarge: AppTypography.heading1.copyWith(
          color: AppColors.textPrimary,
        ),
        headlineMedium: AppTypography.heading2.copyWith(
          color: AppColors.textPrimary,
        ),
        headlineSmall: AppTypography.heading3.copyWith(
          color: AppColors.textPrimary,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(
          color: AppColors.textPrimary,
        ),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
        labelLarge: AppTypography.labelLarge.copyWith(
          color: AppColors.textPrimary,
        ),
        labelMedium: AppTypography.labelMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        labelSmall: AppTypography.labelSmall.copyWith(color: AppColors.primary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        color: AppColors.card,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: AppRadius.circular,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.circular,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.circular,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.circular),
          textStyle: AppTypography.button,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.backgroundDark,
        surfaceContainerHighest: AppColors.cardDark,
        onSurface: AppColors.primary,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      fontFamily: AppTypography.fontFamily,
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(
          color: AppColors.primary,
        ),
        displayMedium: AppTypography.displayMedium.copyWith(
          color: AppColors.primary,
        ),
        headlineLarge: AppTypography.heading1.copyWith(
          color: AppColors.primary,
        ),
        headlineMedium: AppTypography.heading2.copyWith(
          color: AppColors.primary,
        ),
        headlineSmall: AppTypography.heading3.copyWith(
          color: AppColors.primary,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.primary),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: AppColors.primary),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: AppColors.primaryLight,
        ),
        labelLarge: AppTypography.labelLarge.copyWith(color: AppColors.primary),
        labelMedium: AppTypography.labelMedium.copyWith(
          color: AppColors.primary,
        ),
        labelSmall: AppTypography.labelSmall.copyWith(color: AppColors.primary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        color: AppColors.cardDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: AppRadius.circular,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.circular,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.circular,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.circular),
          textStyle: AppTypography.button,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
