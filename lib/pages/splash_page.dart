import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../main.dart' show MainShell, mediaNotificationService;
import '../services/database_service.dart';
import '../services/media_notification_service.dart';
import '../theme/app_theme.dart';

final Logger _log = Logger('SplashPage');

/// Animated splash screen shown on app launch.
///
/// Displays "Melody" with a glow/pulse animation while async initialization
/// runs concurrently. Navigates to [MainShell] once both the minimum
/// display duration (2500 ms) and initialization are complete.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _logoOpacity = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _logoScale = Tween<double>(begin: 0.985, end: 1.015).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _runSplashSequence();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _runSplashSequence() async {
    await WidgetsBinding.instance.endOfFrame;

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
            const MainShell(),
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
      body: Center(
        child: _GlowText(opacity: _logoOpacity, scale: _logoScale),
      ),
    );
  }
}

/// The "Melody" text with smooth breathing animation.
class _GlowText extends StatelessWidget {
  const _GlowText({required this.opacity, required this.scale});

  final Animation<double> opacity;
  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: scale,
        child: Text(
          'Melody',
          style: AppTypography.displayLarge.copyWith(
            fontSize: 42,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
