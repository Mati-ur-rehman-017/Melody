import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path_provider/path_provider.dart';

/// Color data extracted from artwork with animation support
class ExtractedColors {
  final Color primary;
  final Color secondary;
  final Color accent;
  final List<Color> palette;
  final DateTime extractedAt;
  final Color dominantColor;
  final Color mutedColor;
  final Color vibrantColor;
  final Color darkMutedColor;
  final Color lightMutedColor;

  const ExtractedColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.palette,
    required this.extractedAt,
    required this.dominantColor,
    required this.mutedColor,
    required this.vibrantColor,
    required this.darkMutedColor,
    required this.lightMutedColor,
  });
}

/// Controller for managing dynamic colors from artwork with smooth animations
///
/// Extracts comprehensive color palette from track thumbnails and provides
/// animated color transitions for the player interface
class CurrentColor extends ChangeNotifier {
  static final CurrentColor _instance = CurrentColor._internal();
  static CurrentColor get instance => _instance;

  CurrentColor._internal();

  // Currently extracted colors
  ExtractedColors? _currentColors;
  ExtractedColors? _targetColors;
  ExtractedColors? get currentColors => _currentColors;

  // Animation controller for smooth transitions
  AnimationController? _animationController;
  double _animationProgress = 1.0;

  // Cache for extracted colors (track ID -> colors)
  final Map<String, ExtractedColors> _colorCache = {};

  // Maximum cache size
  static const int _maxCacheSize = 50;

  // Fallback colors (when no artwork available) - Dark mode optimized
  static const Color _fallbackPrimary = Color(0xFFE07A5F);
  static const Color _fallbackSecondary = Color(0xFF4A90E2);
  static const Color _fallbackAccent = Color(0xFFF2CC8F);
  static const Color _fallbackDominant = Color(0xFF2C2C2C);
  static const Color _fallbackMuted = Color(0xFF666666);
  static const Color _fallbackVibrant = Color(0xFFE07A5F);
  static const Color _fallbackDarkMuted = Color(0xFF1A1A1A);
  static const Color _fallbackLightMuted = Color(0xFF888888);

  // Getters for current theme colors with fallback
  Color get primaryColor => _interpolateColor(
    _currentColors?.primary ?? _fallbackPrimary,
    _targetColors?.primary ?? _fallbackPrimary,
  );

  Color get secondaryColor => _interpolateColor(
    _currentColors?.secondary ?? _fallbackSecondary,
    _targetColors?.secondary ?? _fallbackSecondary,
  );

  Color get accentColor => _interpolateColor(
    _currentColors?.accent ?? _fallbackAccent,
    _targetColors?.accent ?? _fallbackAccent,
  );

  Color get dominantColor => _interpolateColor(
    _currentColors?.dominantColor ?? _fallbackDominant,
    _targetColors?.dominantColor ?? _fallbackDominant,
  );

  Color get mutedColor => _interpolateColor(
    _currentColors?.mutedColor ?? _fallbackMuted,
    _targetColors?.mutedColor ?? _fallbackMuted,
  );

  Color get vibrantColor => _interpolateColor(
    _currentColors?.vibrantColor ?? _fallbackVibrant,
    _targetColors?.vibrantColor ?? _fallbackVibrant,
  );

  Color get darkMutedColor => _interpolateColor(
    _currentColors?.darkMutedColor ?? _fallbackDarkMuted,
    _targetColors?.darkMutedColor ?? _fallbackDarkMuted,
  );

  Color get lightMutedColor => _interpolateColor(
    _currentColors?.lightMutedColor ?? _fallbackLightMuted,
    _targetColors?.lightMutedColor ?? _fallbackLightMuted,
  );

  List<Color> get palette =>
      _currentColors?.palette ??
      [_fallbackPrimary, _fallbackSecondary, _fallbackAccent];

  /// Initialize with animation controller
  void initialize(TickerProvider vsync) {
    _animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 500),
    );

    _animationController!.addListener(() {
      _animationProgress = _animationController!.value;
      notifyListeners();
    });
  }

  /// Extract colors from an image file with smooth transition
  ///
  /// [imagePath] is the relative path from app documents directory
  /// Returns true if extraction was successful
  Future<bool> extractFromImage(String? imagePath, String trackId) async {
    // Check cache first
    if (_colorCache.containsKey(trackId)) {
      _animateToColors(_colorCache[trackId]!);
      return true;
    }

    if (imagePath == null || imagePath.isEmpty) {
      _animateToColors(null);
      return false;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fullPath = '${appDir.path}/$imagePath';
      final file = File(fullPath);

      if (!await file.exists()) {
        _animateToColors(null);
        return false;
      }

      // Generate palette from image with more colors
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        ResizeImage(FileImage(file), width: 300, height: 300),
        maximumColorCount: 32,
        timeout: const Duration(seconds: 3),
      );

      // Extract comprehensive color palette
      final extractedColors = _extractComprehensiveColors(paletteGenerator);

      if (extractedColors == null) {
        _animateToColors(null);
        return false;
      }

      // Cache the result
      _addToCache(trackId, extractedColors);

      // Animate to new colors
      _animateToColors(extractedColors);
      return true;
    } catch (e) {
      debugPrint('Error extracting colors: $e');
      _animateToColors(null);
      return false;
    }
  }

  /// Extract comprehensive color palette from generator
  ExtractedColors? _extractComprehensiveColors(PaletteGenerator generator) {
    final colors = generator.colors.toList();
    if (colors.isEmpty) return null;

    // Get specific palette colors
    final dominant = generator.dominantColor?.color ?? colors.first;
    final vibrant = generator.vibrantColor?.color ?? colors.first;
    final muted = generator.mutedColor?.color ?? colors.first;
    final darkMuted =
        generator.darkMutedColor?.color ?? const Color(0xFF1A1A1A);
    final lightMuted =
        generator.lightMutedColor?.color ?? const Color(0xFF888888);

    // Sort remaining colors by luminance for variety
    final otherColors = colors
        .where((c) => c != dominant && c != vibrant && c != muted)
        .toList();

    otherColors.sort(
      (a, b) => b.computeLuminance().compareTo(a.computeLuminance()),
    );

    // Build comprehensive palette
    final primary = vibrant;
    final secondary = otherColors.isNotEmpty ? otherColors.first : muted;
    final accent = otherColors.length > 1 ? otherColors.last : lightMuted;

    // Build full palette list (up to 8 colors)
    final palette = <Color>[
      primary,
      secondary,
      accent,
      if (dominant != primary) dominant,
      if (vibrant != primary) vibrant,
      muted,
      darkMuted,
      lightMuted,
    ].take(8).toList();

    return ExtractedColors(
      primary: primary,
      secondary: secondary,
      accent: accent,
      palette: palette,
      extractedAt: DateTime.now(),
      dominantColor: dominant,
      mutedColor: muted,
      vibrantColor: vibrant,
      darkMutedColor: darkMuted,
      lightMutedColor: lightMuted,
    );
  }

  /// Animate to new colors
  void _animateToColors(ExtractedColors? newColors) {
    if (_animationController == null) {
      _currentColors = newColors;
      notifyListeners();
      return;
    }

    _targetColors = newColors;
    _animationController!.forward(from: 0.0).then((_) {
      _currentColors = _targetColors;
      _animationProgress = 1.0;
    });
  }

  /// Interpolate between two colors based on animation progress
  Color _interpolateColor(Color from, Color to) {
    if (_animationProgress >= 1.0 || _currentColors == _targetColors) {
      return to;
    }

    return Color.lerp(from, to, _animationProgress) ?? to;
  }

  /// Add extracted colors to cache with LRU eviction
  void _addToCache(String trackId, ExtractedColors colors) {
    // Evict oldest if cache is full
    if (_colorCache.length >= _maxCacheSize) {
      final oldestKey = _colorCache.entries
          .reduce(
            (a, b) => a.value.extractedAt.isBefore(b.value.extractedAt) ? a : b,
          )
          .key;
      _colorCache.remove(oldestKey);
    }

    _colorCache[trackId] = colors;
  }

  /// Clear the color cache
  void clearCache() {
    _colorCache.clear();
    notifyListeners();
  }

  /// Get a color with alpha for backgrounds
  Color getBackgroundColor({double alpha = 0.9}) {
    return dominantColor.withAlpha((255 * alpha).round());
  }

  /// Get a contrasting text color (white or black) based on background
  Color getTextColor({bool isPrimary = true}) {
    final bgColor = isPrimary ? primaryColor : accentColor;
    final luminance = bgColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Get a gradient from the palette
  LinearGradient getBackgroundGradient({
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
    double alpha = 0.9,
  }) {
    final colors = palette.length >= 2
        ? [palette[0], palette[1]]
        : [primaryColor, accentColor];

    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors.map((c) => c.withAlpha((255 * alpha).round())).toList(),
    );
  }

  /// Get a glassmorphism-compatible color
  Color getGlassColor({double alpha = 0.3}) {
    return darkMutedColor.withAlpha((255 * alpha).round());
  }

  /// Get glow color for effects
  Color getGlowColor({double alpha = 0.5}) {
    return vibrantColor.withAlpha((255 * alpha).round());
  }

  /// Reset to fallback colors with animation
  void reset() {
    _animateToColors(null);
  }

  @override
  void dispose() {
    _animationController?.dispose();
    clearCache();
    super.dispose();
  }
}
