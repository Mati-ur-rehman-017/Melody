import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:logging/logging.dart';

import 'pages/discover_page.dart';
import 'pages/library_page.dart';
import 'pages/splash_page.dart';
import 'services/media_notification_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'widgets/mini_player.dart';

MediaNotificationService? mediaNotificationService;
final ThemeService _themeService = ThemeService();
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.dark,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  JustAudioMediaKit.ensureInitialized();

  _setupLogging();
  await _loadThemePreference();

  runApp(const MelodyApp());
}

Future<void> _loadThemePreference() async {
  final isDarkMode = await _themeService.loadThemePreference();
  themeModeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
}

/// Setup logging for debug output
void _setupLogging() {
  if (kReleaseMode) {
    Logger.root.level = Level.OFF;
  } else {
    Logger.root.level = Level.ALL;
  }

  Logger.root.onRecord.listen((record) {
    debugPrint(
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
  });
}

/// Main application widget with Melody Modern Dark theme
class MelodyApp extends StatelessWidget {
  const MelodyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'melody',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const SplashPage(),
        );
      },
    );
  }
}

/// Main shell with floating pill navigation and mini-player
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _pages = const [DiscoverPage(), LibraryPage()];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Handle page change from swipe
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Handle navigation tab tap
  void _onNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _toggleTheme() async {
    final isDarkMode = themeModeNotifier.value == ThemeMode.dark;
    final nextMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    themeModeNotifier.value = nextMode;
    await _themeService.saveThemePreference(nextMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content with PageView for swipe navigation
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: _pages,
          ),

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
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeNotifier,
              builder: (context, themeMode, child) {
                return _buildFloatingNavigation(themeMode);
              },
            ),
          ),

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
  Widget _buildFloatingNavigation(ThemeMode themeMode) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = themeMode == ThemeMode.dark;

    return Container(
      key: const ValueKey('floating-navigation'),
      height: 64,
      decoration: BoxDecoration(
        color: isDarkMode ? colorScheme.surfaceContainerHighest : Colors.white,
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
              onTap: () => _onNavTap(0),
            ),
          ),

          // Library tab - takes 50% width
          Expanded(
            child: _buildNavItem(
              icon: Icons.library_music,
              label: 'Library',
              isSelected: _currentIndex == 1,
              onTap: () => _onNavTap(1),
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
    final colorScheme = Theme.of(context).colorScheme;

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
                  color: isSelected
                      ? AppColors.fallbackPrimary
                      : colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 24,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.fallbackPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _toggleTheme,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          boxShadow: AppShadows.card,
        ),
        child: Icon(
          isDarkMode ? Icons.light_mode : Icons.dark_mode,
          color: Theme.of(context).colorScheme.onSurface,
          size: 18,
        ),
      ),
    );
  }
}
