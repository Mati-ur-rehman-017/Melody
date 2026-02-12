import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:logging/logging.dart';

import 'pages/discover_page.dart';
import 'pages/library_page.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';
import 'widgets/mini_player.dart';

void main() async {
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaKit for Linux/Windows desktop audio support
  JustAudioMediaKit.ensureInitialized();

  // Initialize logging
  _setupLogging();

  // Initialize database
  await DatabaseService.instance.initialize();

  runApp(const MelodyApp());
}

/// Setup logging for debug output
void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint(
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
  });
}

/// Main application widget with Melody Bubbly theme
class MelodyApp extends StatefulWidget {
  const MelodyApp({super.key});

  @override
  State<MelodyApp> createState() => _MelodyAppState();
}

class _MelodyAppState extends State<MelodyApp> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Melody',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MainShell(isDarkMode: _isDarkMode, onToggleTheme: _toggleTheme),
    );
  }
}

/// Main shell with floating pill navigation and mini-player
class MainShell extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainShell({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [DiscoverPage(), LibraryPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          _pages[_currentIndex],

          // Mini player (shows when audio is playing)
          const Positioned(
            bottom: 90, // Above the floating nav
            left: 0,
            right: 0,
            child: MiniPlayer(),
          ),

          // Floating pill navigation
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: _buildFloatingNavigation(),
          ),

          // Theme toggle button - aligned with header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, right: 16),
              child: Align(
                alignment: Alignment.topRight,
                child: _buildThemeToggle(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build floating pill navigation bar
  Widget _buildFloatingNavigation() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: AppRadius.circular,
        boxShadow: AppShadows.navigation,
      ),
      child: Row(
        children: [
          // Explore tab - takes 50% width
          Expanded(
            child: _buildNavItem(
              icon: Icons.explore,
              label: 'Explore',
              isSelected: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
          ),

          // Library tab - takes 50% width
          Expanded(
            child: _buildNavItem(
              icon: Icons.library_music,
              label: 'Library',
              isSelected: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual navigation item
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 64,
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  color: isSelected ? AppColors.primary : Colors.white54,
                  size: 24,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build theme toggle button
  Widget _buildThemeToggle() {
    return GestureDetector(
      onTap: widget.onToggleTheme,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: widget.isDarkMode ? AppColors.cardDark : AppColors.card,
          shape: BoxShape.circle,
          boxShadow: AppShadows.bubbly,
        ),
        child: Icon(
          widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
          color: widget.isDarkMode ? Colors.white : AppColors.secondary,
          size: 18,
        ),
      ),
    );
  }
}
