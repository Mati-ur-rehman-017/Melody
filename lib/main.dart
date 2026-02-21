import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:logging/logging.dart';

import 'pages/discover_page.dart';
import 'pages/library_page.dart';
import 'services/database_service.dart';
import 'services/media_notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/mini_player.dart';

MediaNotificationService? mediaNotificationService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  JustAudioMediaKit.ensureInitialized();

  _setupLogging();

  await DatabaseService.instance.initialize();

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      debugPrint('[INFO] Initializing AudioService...');
      mediaNotificationService = await AudioService.init(
        builder: () => MediaNotificationService(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.melody.app.audio',
          androidNotificationChannelName: 'Audio Playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      ).timeout(const Duration(seconds: 10));
      debugPrint('[INFO] AudioService initialized successfully');
    } catch (e, stack) {
      debugPrint('[ERROR] Failed to initialize AudioService: $e');
      debugPrint('[ERROR] Stack: $stack');
    }
  }

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

/// Main application widget with Melody Modern Dark theme
class MelodyApp extends StatelessWidget {
  const MelodyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Melody',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainShell(),
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
            child: _buildFloatingNavigation(),
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
}
