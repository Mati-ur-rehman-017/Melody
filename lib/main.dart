import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:logging/logging.dart';

import 'pages/library_page.dart';
import 'pages/search_page.dart';
import 'services/database_service.dart';
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

class MelodyApp extends StatelessWidget {
  const MelodyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Melody',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

/// Main shell with bottom navigation and mini-player
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Row(
          children: [
            Icon(Icons.music_note),
            SizedBox(width: 8),
            Text('Melody'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Main content area with page switching
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [SearchPage(), LibraryPage()],
            ),
          ),

          // Mini player (shows when audio is playing)
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}
