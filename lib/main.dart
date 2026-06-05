import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:logging/logging.dart';

import 'pages/discover_page.dart';
import 'pages/downloading_page.dart';
import 'pages/playlists_page.dart';
import 'pages/songs_page.dart';
import 'pages/splash_page.dart';
import 'services/download_manager_service.dart';
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

  // Initialize download manager (loads persisted tasks from DB)
  await DownloadManagerService.instance.initialize();

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

/// Main shell with bottom navigation bar and mini-player
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late PageController _pageController;
  int _activeDownloadCount = 0;
  late final DownloadManagerService _downloadManager;

  final List<Widget> _pages = const [
    DiscoverPage(),
    SongsPage(),
    DownloadingPage(),
    PlaylistsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _downloadManager = DownloadManagerService.instance;
    _activeDownloadCount = _downloadManager.activeTasks.length;
    _downloadManager.addListener(_onDownloadsChanged);
  }

  @override
  void dispose() {
    _downloadManager.removeListener(_onDownloadsChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onDownloadsChanged() {
    setState(() {
      _activeDownloadCount = _downloadManager.activeTasks.length;
    });
  }

  /// Handle page change from swipe
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Handle navigation tab tap
  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        type: BottomNavigationBarType.fixed,
        elevation: 4,
        selectedItemColor: const Color(0xFFE07A5F),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.library_music),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: _activeDownloadCount > 0
                ? Badge(
                    label: Text('$_activeDownloadCount'),
                    child: const Icon(Icons.download_outlined),
                  )
                : const Icon(Icons.download_outlined),
            activeIcon: _activeDownloadCount > 0
                ? Badge(
                    label: Text('$_activeDownloadCount'),
                    child: const Icon(Icons.download),
                  )
                : const Icon(Icons.download),
            label: 'Downloading',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.queue_music),
            label: 'Playlists',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content with PageView for swipe navigation
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: _pages,
          ),

          // Mini player (shows when audio is playing)
          const Positioned(bottom: 0, left: 0, right: 0, child: MiniPlayer()),

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
