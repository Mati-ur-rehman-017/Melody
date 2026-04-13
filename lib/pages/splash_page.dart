import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:logging/logging.dart';

import '../main.dart' show mediaNotificationService;
import '../services/database_service.dart';
import '../services/media_notification_service.dart';
import '../theme/app_theme.dart';

final Logger _log = Logger('SplashPage');

/// Animated splash screen shown on app launch.
///
/// Displays "Melody" with a glow/pulse animation while async initialization
/// runs concurrently. Navigates to [MainShell] once both the minimum
/// display duration (2500ms) and initialization are complete.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _runSplashSequence();
  }

  Future<void> _runSplashSequence() async {
    // Run initialization and minimum display duration concurrently
    await Future.wait([
      _initialize(),
      Future.delayed(const Duration(milliseconds: 2500)),
    ]);

    if (!mounted) return;
    _navigateToMain();
  }

  Future<void> _initialize() async {
    try {
      await DatabaseService.instance.initialize();
    } catch (e, stack) {
      _log.severe('Failed to initialize database: $e');
      _log.fine('Stack: $stack');
    }

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        _log.info('Initializing AudioService...');
        mediaNotificationService = await AudioService.init(
          builder: () => MediaNotificationService(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.melody.app.audio',
            androidNotificationChannelName: 'Audio Playback',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
          ),
        ).timeout(const Duration(seconds: 10));
        _log.info('AudioService initialized successfully');
      } catch (e, stack) {
        _log.severe('Failed to initialize AudioService: $e');
        _log.fine('Stack: $stack');
      }
    }
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _MainShellPlaceholder(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(child: _GlowText()),
    );
  }
}

/// The "Melody" text with the three-phase glow/pulse animation.
class _GlowText extends StatelessWidget {
  const _GlowText();

  @override
  Widget build(BuildContext context) {
    return Text(
          'Melody',
          style: AppTypography.displayLarge.copyWith(
            fontSize: 42,
            color: Colors.white,
          ),
        )
        // Phase 1: fade in (0–800ms)
        .animate()
        .fadeIn(duration: 800.ms, curve: Curves.easeOut)
        // Phase 2: glow shimmer pulse ×2 (800ms–2200ms)
        .shimmer(
          delay: 800.ms,
          duration: 700.ms,
          color: Colors.white.withValues(alpha: 0.5),
        )
        .shimmer(
          delay: 1450.ms,
          duration: 700.ms,
          color: Colors.white.withValues(alpha: 0.5),
        )
        // Phase 3: settle — slight fade on glow to clean white (implicit via shimmer end)
        .then(delay: 2200.ms);
  }
}

// Temporary placeholder — replaced in Task 2 after main.dart is updated.
// This avoids a circular dependency during this task.
class _MainShellPlaceholder extends StatelessWidget {
  const _MainShellPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Color(0xFF000000));
  }
}
