import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage theme persistence
///
/// Saves and loads the user's theme preference (dark/light mode)
/// using SharedPreferences for persistence across app restarts.
class ThemeService {
  static const String _themeKey = 'is_dark_mode';

  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  /// Load the saved theme preference
  ///
  /// Returns true for dark mode, false for light mode
  /// Defaults to light mode (false) if no preference is saved
  Future<bool> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_themeKey) ?? false;
    } catch (e) {
      // If there's an error loading preferences, default to light mode
      return false;
    }
  }

  /// Save the theme preference
  ///
  /// [isDarkMode] - true for dark mode, false for light mode
  Future<void> saveThemePreference(bool isDarkMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, isDarkMode);
    } catch (e) {
      // Silently fail if we can't save preferences
      // The app will still work, just won't persist the theme
    }
  }
}
