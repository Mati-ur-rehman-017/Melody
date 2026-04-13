import 'dart:ui';

import 'package:flutter/material.dart';

/// Melody Modern Dark Theme
///
/// Inspired by Namida's sleek, dark-first design with dynamic artwork colors.
/// Pure OLED black background with glassmorphism effects.
/// Colors adapt dynamically from album artwork.

class AppColors {
  // OLED Black - True black for dark mode
  static const Color background = Color(0xFF000000);
  static const Color backgroundElevated = Color(0xFF121212);
  static const Color backgroundCard = Color(0xFF1E1E1E);

  // Dynamic colors - will be overridden by artwork extraction
  static Color primary = const Color(0xFFE67E5F);
  static Color accent = const Color(0xFFF4C430);
  static List<Color> palette = [primary, accent];

  // Fallback colors when no artwork
  static const Color fallbackPrimary = Color(0xFFE07A5F);
  static const Color fallbackAccent = Color(0xFFF2CC8F);

  // Text colors for dark theme
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF666666);

  // UI Colors
  static const Color divider = Color(0xFF282828);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceHighlight = Color(0xFF2A2A2A);

  // Glassmorphism
  static const Color glassBackground = Color(0x80000000);
  static const Color glassBorder = Color(0x20FFFFFF);

  // Status colors
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFFB300);

  // Transparency helpers
  static const Color transparent = Colors.transparent;

  // Backward compatibility - map old names to new dark theme
  static Color get card => backgroundCard;
  static Color get secondary => backgroundElevated;
  static Color get primaryLight => textSecondary;
  static Color get primaryDark => textPrimary;
  static Color get backgroundDark => background;
  static Color get cardDark => backgroundCard;
  static Color get textLight => textPrimary;
  static Color get shadowColor => Colors.black;

  // Category colors for backward compatibility
  static Color get categoryTouching => primary;
  static Color get categoryListening =>
      const Color(0xFF1DB954); // Spotify green
  static Color get categorySpeaking => const Color(0xFF1E90FF); // Blue
  static Color get categoryVisual => const Color(0xFFFF6B6B); // Red
  static Color get categoryFocus => const Color(0xFF9B59B6); // Purple

  // Track backgrounds (now all dark)
  static Color get trackBg1 => surface;
  static Color get trackBg2 => surfaceHighlight;
  static Color get trackBg3 => surface;
  static Color get trackBg4 => surfaceHighlight;

  /// Reset to fallback colors
  static void resetToFallback() {
    primary = fallbackPrimary;
    accent = fallbackAccent;
    palette = [fallbackPrimary, fallbackAccent];
  }

  /// Update dynamic colors from extracted palette
  static void updateFromPalette(List<Color> extractedColors) {
    if (extractedColors.isNotEmpty) {
      primary = extractedColors.first;
      accent = extractedColors.length > 1
          ? extractedColors.last
          : extractedColors.first;
      palette = extractedColors;
    }
  }
}

/// Glassmorphism utilities for modern blur effects
class Glassmorphism {
  /// Standard glass effect - 20 blur
  static Widget blur({
    required Widget child,
    double sigmaX = 20,
    double sigmaY = 20,
    Color? overlayColor,
  }) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          decoration: BoxDecoration(
            color: overlayColor ?? AppColors.glassBackground,
          ),
          child: child,
        ),
      ),
    );
  }

  /// Heavy glass effect - 30 blur for backgrounds
  static Widget heavyBlur({required Widget child, Color? overlayColor}) {
    return blur(
      sigmaX: 30,
      sigmaY: 30,
      overlayColor: overlayColor ?? AppColors.glassBackground,
      child: child,
    );
  }

  /// Light glass effect - 10 blur for subtle overlays
  static Widget lightBlur({required Widget child, Color? overlayColor}) {
    return blur(
      sigmaX: 10,
      sigmaY: 10,
      overlayColor: overlayColor ?? AppColors.glassBackground.withAlpha(128),
      child: child,
    );
  }

  /// Glass card with border
  static Widget card({
    required Widget child,
    double borderRadius = 16,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.glassBackground,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Modern shadow system for dark theme
class AppShadows {
  /// Colored glow shadow - uses primary color
  static List<BoxShadow> glow(Color color, {double intensity = 0.3}) {
    return [
      BoxShadow(
        color: color.withAlpha((255 * intensity).round()),
        blurRadius: 20,
        spreadRadius: -5,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Subtle elevation shadow
  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: Colors.black.withAlpha(76),
      blurRadius: 10,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
  ];

  /// Card shadow for dark surfaces
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withAlpha(128),
      blurRadius: 20,
      spreadRadius: -5,
      offset: const Offset(0, 8),
    ),
  ];

  /// Bottom navigation shadow
  static List<BoxShadow> get navigation => [
    BoxShadow(
      color: Colors.black.withAlpha(179),
      blurRadius: 20,
      spreadRadius: -5,
      offset: const Offset(0, -4),
    ),
  ];

  // Backward compatibility
  static List<BoxShadow> get bubbly => card;
  static List<BoxShadow> get elevated => glow(Colors.white, intensity: 0.1);
  static List<BoxShadow> get miniPlayer => navigation;
}

/// Modern radius system (reduced from bubbly to modern)
class AppRadius {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double full = 999;

  // BorderRadius helpers
  static BorderRadius get zero => BorderRadius.circular(none);
  static BorderRadius get extraSmall => BorderRadius.circular(xs);
  static BorderRadius get small => BorderRadius.circular(sm);
  static BorderRadius get medium => BorderRadius.circular(md);
  static BorderRadius get large => BorderRadius.circular(lg);
  static BorderRadius get xLarge => BorderRadius.circular(xl);
  static BorderRadius get xxLarge => BorderRadius.circular(xxl);
  static BorderRadius get circular => BorderRadius.circular(full);
}

/// Typography system
class AppTypography {
  static const String fontFamily = 'Plus Jakarta Sans';

  // Font Weights
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // Display styles
  static TextStyle get displayLarge => const TextStyle(
    fontFamily: fontFamily,
    fontWeight: bold,
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

  // Heading styles
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

  // Body styles
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

  // Label styles
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

/// Main application theme - Dark only
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.fallbackPrimary,
        brightness: Brightness.light,
        primary: AppColors.fallbackPrimary,
        secondary: AppColors.fallbackAccent,
        surface: const Color(0xFFF8F7F4),
        onSurface: const Color(0xFF1F1F1F),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F7F4),
      fontFamily: AppTypography.fontFamily,
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(
          color: const Color(0xFF1F1F1F),
        ),
        displayMedium: AppTypography.displayMedium.copyWith(
          color: const Color(0xFF1F1F1F),
        ),
        headlineLarge: AppTypography.heading1.copyWith(
          color: const Color(0xFF1F1F1F),
        ),
        headlineMedium: AppTypography.heading2.copyWith(
          color: const Color(0xFF1F1F1F),
        ),
        headlineSmall: AppTypography.heading3.copyWith(
          color: const Color(0xFF1F1F1F),
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(
          color: const Color(0xFF1F1F1F),
        ),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          color: const Color(0xFF1F1F1F),
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: const Color(0xFF555555),
        ),
        labelLarge: AppTypography.labelLarge.copyWith(
          color: const Color(0xFF1F1F1F),
        ),
        labelMedium: AppTypography.labelMedium.copyWith(
          color: const Color(0xFF555555),
        ),
        labelSmall: AppTypography.labelSmall.copyWith(
          color: const Color(0xFF777777),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(color: AppColors.fallbackPrimary, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.fallbackPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
          textStyle: AppTypography.button,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.fallbackPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF1F1F1F), size: 24),
    );
  }

  static ThemeData get darkTheme => theme;

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        secondary: Color(0xFFB3B3B3),
        surface: Color(0xFF121212),
        surfaceContainerHighest: Color(0xFF1E1E1E),
        onSurface: Colors.white,
        outline: Color(0xFF282828),
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
          color: AppColors.textSecondary,
        ),
        labelSmall: AppTypography.labelSmall.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        color: AppColors.backgroundCard,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: const BorderSide(color: Colors.white, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
          textStyle: AppTypography.button,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: CircleBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.white,
        unselectedItemColor: Color(0xFF666666),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.white,
        inactiveTrackColor: AppColors.divider,
        thumbColor: Colors.white,
        overlayColor: Colors.white.withAlpha(25),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      iconTheme: const IconThemeData(color: Colors.white, size: 24),
    );
  }
}

/// Extension for easy color animations
extension ColorAnimation on Color {
  /// Animate to another color over a duration
  Animation<Color?> animateTo(Color target, AnimationController controller) {
    return ColorTween(
      begin: this,
      end: target,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }
}

/// Utility for smooth color transitions
class ColorTransition extends StatelessWidget {
  final Animation<Color?> animation;
  final Widget Function(BuildContext context, Color? color) builder;

  const ColorTransition({
    super.key,
    required this.animation,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return builder(context, animation.value);
      },
    );
  }
}
