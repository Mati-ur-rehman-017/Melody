import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../controller/current_color.dart';
import '../controller/miniplayer_controller.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import 'party_mode.dart';
import 'playback_speed_dialog.dart';
import 'queue_view.dart';
import 'waveform.dart';

/// Unified miniplayer with 3 states: minimized, expanded, and queue
class NamidaMiniPlayer extends StatefulWidget {
  const NamidaMiniPlayer({super.key});

  @override
  State<NamidaMiniPlayer> createState() => _NamidaMiniPlayerState();
}

class _NamidaMiniPlayerState extends State<NamidaMiniPlayer>
    with TickerProviderStateMixin {
  late final MiniPlayerController _controller;
  late final CurrentColor _colorController;
  StreamSubscription<Track?>? _trackSubscription;

  @override
  void initState() {
    super.initState();
    _controller = MiniPlayerController.instance;
    _colorController = CurrentColor.instance;
    _controller.initialize(this);
    _colorController.initialize(this);

    _trackSubscription = AudioPlayerService.instance.playingTrackStream.listen((
      track,
    ) {
      if (track != null) {
        _colorController.extractFromImage(track.thumbnailPath, track.id);
      }
    });

    // Extract for the initially playing track if there is one
    final initialTrack = AudioPlayerService.instance.currentTrackInQueue;
    if (initialTrack != null) {
      _colorController.extractFromImage(
        initialTrack.thumbnailPath,
        initialTrack.id,
      );
    }
  }

  @override
  void dispose() {
    _trackSubscription?.cancel();
    CurrentColor.instance.disposeAnimation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: AudioPlayerService.instance.playerStateStream,
      builder: (context, stateSnapshot) {
        final playerState = stateSnapshot.data;
        final processingState = playerState?.processingState;
        final currentTrack = AudioPlayerService.instance.currentTrackInQueue;

        if (currentTrack == null || processingState == ProcessingState.idle) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight;
            final maxWidth = constraints.maxWidth;

            _controller.setMaxOffset(maxHeight);

            return AnimatedBuilder(
              animation:
                  _controller.animation ?? const AlwaysStoppedAnimation(0.0),
              builder: (context, child) {
                final animationValue = _controller.animationValue;

                return Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _calculateBottomPosition(
                        animationValue,
                        maxHeight,
                      ),
                      height: _calculateHeight(animationValue, maxHeight),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        dragStartBehavior: DragStartBehavior.down,
                        onTap: _controller.canHandleTap
                            ? () => _controller.onMiniPlayerTap()
                            : null,
                        onVerticalDragStart: (details) =>
                            _controller.onVerticalDragStart(details, maxHeight),
                        onVerticalDragUpdate: (details) => _controller
                            .onVerticalDragUpdate(details, maxHeight),
                        onVerticalDragEnd: (details) =>
                            _controller.onVerticalDragEnd(details, maxHeight),
                        child: _buildPlayerContent(
                          context,
                          animationValue,
                          currentTrack,
                          maxWidth,
                          maxHeight,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  double _calculateBottomPosition(double value, double maxHeight) {
    if (value < 0.5) {
      return (1 - value * 2) * 90;
    }
    return 0;
  }

  double _calculateHeight(double value, double maxHeight) {
    if (value < 0.5) {
      return 64 + (value * 2) * (maxHeight - 64);
    }
    return maxHeight;
  }

  Widget _buildPlayerContent(
    BuildContext context,
    double animationValue,
    Track track,
    double maxWidth,
    double maxHeight,
  ) {
    final isMinimized = animationValue < 0.5;
    final expandedProgress = (animationValue * 2).clamp(0.0, 1.0);
    final queueProgress = animationValue > 1.0
        ? ((animationValue - 1.0) * 2).clamp(0.0, 1.0)
        : 0.0;

    return ListenableBuilder(
      listenable: _colorController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: _colorController.primaryColor.withValues(alpha: 0.95),
            borderRadius: isMinimized
                ? BorderRadius.circular(16)
                : BorderRadius.zero,
            boxShadow: isMinimized
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!isMinimized) _buildBackgroundImage(expandedProgress, track),
              if (!isMinimized)
                PartyModeContainer(
                  opacity: expandedProgress,
                  color: _colorController.accentColor,
                ),
              if (isMinimized)
                _buildMinimizedContent(track)
              else
                _buildExpandedContent(
                  context,
                  track,
                  expandedProgress,
                  queueProgress,
                  maxWidth,
                  maxHeight,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackgroundImage(double opacity, Track track) {
    if (track.thumbnailPath == null) {
      return Container(
        color: _colorController.primaryColor.withValues(alpha: 0.8),
      );
    }

    return FutureBuilder<String?>(
      future: _getFullThumbnailPath(track.thumbnailPath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            color: _colorController.primaryColor.withValues(alpha: 0.8),
          );
        }

        return Opacity(
          opacity: opacity * 0.6,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Image.file(
              File(snapshot.data!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMinimizedContent(Track track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildThumbnail(track, 48, 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  track.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  track.author,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildControlButton(
            Icons.skip_previous,
            () => AudioPlayerService.instance.previous(),
          ),
          _buildPlayPauseButton(size: 44),
          _buildControlButton(
            Icons.skip_next,
            () => AudioPlayerService.instance.next(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(
    BuildContext context,
    Track track,
    double expandedProgress,
    double queueProgress,
    double maxWidth,
    double maxHeight,
  ) {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(expandedProgress),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 1 - queueProgress,
                    child: Center(child: _buildArtworkSection(track, maxWidth)),
                  ),
                ),
                if (queueProgress > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: maxHeight * 0.35,
                    child: Opacity(
                      opacity: queueProgress,
                      child: QueueView(
                        scrollController: _controller.queueScrollController,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Opacity(
            opacity: 1 - (queueProgress * 0.5),
            child: _buildBottomControls(track),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkSection(Track track, double maxWidth) {
    final artworkSize = maxWidth * 0.65;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => AudioPlayerService.instance.togglePlayPause(),
          child: Container(
            width: artworkSize,
            height: artworkSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildThumbnail(track, artworkSize, 0),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Text(
                track.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                track.author,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(Track track) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WaveformComponent(
            duration: track.duration ?? Duration.zero,
            color: _colorController.accentColor,
          ),
          const SizedBox(height: 16),
          StreamBuilder<Duration>(
            stream: AudioPlayerService.instance.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = track.duration ?? Duration.zero;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                Icons.skip_previous,
                () => AudioPlayerService.instance.previous(),
                size: 40,
              ),
              const SizedBox(width: 24),
              _buildPlayPauseButton(size: 72),
              const SizedBox(width: 24),
              _buildControlButton(
                Icons.skip_next,
                () => AudioPlayerService.instance.next(),
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildShuffleButton(),
              _buildUtilityButton(
                Icons.queue_music,
                () => _controller.onQueueButtonTap(),
                badge: _getQueueCount(),
              ),
              _buildRepeatButton(),
              _buildSleepTimerButton(),
              _buildSpeedButton(),
              _buildUtilityButton(Icons.volume_up, () => _showVolumeDialog()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(double opacity) {
    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => _controller.onMinimizeButtonTap(),
              icon: const Icon(Icons.keyboard_arrow_down),
              color: Colors.white,
              iconSize: 32,
            ),
            Text(
              'Now Playing',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            IconButton(
              onPressed: () => _showMoreOptions(),
              icon: const Icon(Icons.more_vert),
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(Track track, double size, double borderRadius) {
    if (track.thumbnailPath == null) {
      return _buildPlaceholder(size, borderRadius);
    }

    return FutureBuilder<String?>(
      future: _getFullThumbnailPath(track.thumbnailPath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildPlaceholder(size, borderRadius);
        }

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: Colors.grey[800],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(snapshot.data!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildPlaceholder(size, borderRadius),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(double size, double borderRadius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.grey[800],
      ),
      child: Icon(
        Icons.music_note,
        color: Colors.white.withValues(alpha: 0.5),
        size: size * 0.4,
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    VoidCallback onPressed, {
    double size = 36,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: Colors.white,
      iconSize: size,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildPlayPauseButton({required double size}) {
    return StreamBuilder<PlayerState>(
      stream: AudioPlayerService.instance.playerStateStream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data?.playing ?? false;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _colorController.accentColor,
            boxShadow: [
              BoxShadow(
                color: _colorController.accentColor.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => AudioPlayerService.instance.togglePlayPause(),
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.black,
            ),
            iconSize: size * 0.5,
            padding: EdgeInsets.zero,
          ),
        );
      },
    );
  }

  Widget _buildUtilityButton(
    IconData icon,
    VoidCallback onPressed, {
    int? badge,
  }) {
    return Stack(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: Colors.white.withValues(alpha: 0.8),
          iconSize: 24,
        ),
        if (badge != null && badge > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _colorController.accentColor,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badge.toString(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRepeatButton() {
    return StreamBuilder<RepeatMode>(
      stream: AudioPlayerService.instance.repeatModeStream,
      builder: (context, snapshot) {
        final repeatMode = snapshot.data ?? RepeatMode.all;
        IconData icon;
        switch (repeatMode) {
          case RepeatMode.one:
            icon = Icons.repeat_one;
            break;
          case RepeatMode.off:
            icon = Icons.repeat;
            break;
          default:
            icon = Icons.repeat;
        }

        return IconButton(
          onPressed: () => AudioPlayerService.instance.toggleRepeatMode(),
          icon: Icon(icon),
          color: repeatMode != RepeatMode.off
              ? _colorController.accentColor
              : Colors.white.withValues(alpha: 0.8),
          iconSize: 24,
        );
      },
    );
  }

  Widget _buildSleepTimerButton() {
    final hasTimer = AudioPlayerService.instance.sleepTimerEndTime != null;

    return Stack(
      children: [
        IconButton(
          onPressed: () => _showSleepTimerDialog(),
          icon: Icon(hasTimer ? Icons.bedtime : Icons.bedtime_outlined),
          color: hasTimer
              ? _colorController.accentColor
              : Colors.white.withValues(alpha: 0.8),
          iconSize: 24,
        ),
        if (hasTimer)
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _colorController.accentColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShuffleButton() {
    return StreamBuilder<bool>(
      stream: AudioPlayerService.instance.shuffleStream,
      initialData: AudioPlayerService.instance.isShuffleEnabled,
      builder: (context, snapshot) {
        final isShuffleEnabled = snapshot.data ?? false;

        return IconButton(
          onPressed: () => AudioPlayerService.instance.toggleShuffle(),
          icon: Icon(
            isShuffleEnabled ? Icons.shuffle_on_outlined : Icons.shuffle,
          ),
          color: isShuffleEnabled
              ? _colorController.accentColor
              : Colors.white.withValues(alpha: 0.8),
          iconSize: 24,
        );
      },
    );
  }

  Widget _buildSpeedButton() {
    return StreamBuilder<double>(
      stream: AudioPlayerService.instance.speedStream,
      initialData: AudioPlayerService.instance.playbackSpeed,
      builder: (context, snapshot) {
        final speed = snapshot.data ?? 1.0;
        final isNotNormal = speed != 1.0;

        return Stack(
          children: [
            IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const PlaybackSpeedDialog(),
                );
              },
              icon: const Icon(Icons.speed),
              color: isNotNormal
                  ? _colorController.accentColor
                  : Colors.white.withValues(alpha: 0.8),
              iconSize: 24,
            ),
            if (isNotNormal)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _colorController.accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${speed}x',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<String?> _getFullThumbnailPath(String? thumbnailPath) async {
    if (thumbnailPath == null) return null;
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$thumbnailPath';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  int _getQueueCount() {
    return AudioPlayerService.instance.queue.length;
  }

  void _showVolumeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Volume', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Volume control not implemented yet',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Share', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.white),
              title: const Text(
                'Remove from queue',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showSleepTimerDialog() {
    final currentEndTime = AudioPlayerService.instance.sleepTimerEndTime;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Sleep Timer', style: TextStyle(color: Colors.white)),
        content: currentEndTime != null
            ? Text(
                'Timer ends at ${currentEndTime.hour}:${currentEndTime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white70),
              )
            : const Text(
                'Set a timer to stop playback',
                style: TextStyle(color: Colors.white70),
              ),
        actions: [
          if (currentEndTime != null)
            TextButton(
              onPressed: () {
                AudioPlayerService.instance.cancelSleepTimer();
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel Timer',
                style: TextStyle(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () {
              AudioPlayerService.instance.setSleepTimer(
                duration: const Duration(minutes: 30),
              );
              Navigator.pop(context);
            },
            child: const Text('30 min'),
          ),
          TextButton(
            onPressed: () {
              AudioPlayerService.instance.setSleepTimer(
                duration: const Duration(minutes: 60),
              );
              Navigator.pop(context);
            },
            child: const Text('1 hour'),
          ),
        ],
      ),
    );
  }
}
