import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../controller/current_color.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/waveform_service.dart';
import '../theme/app_theme.dart';
import '../widgets/playback_speed_dialog.dart';
import '../widgets/sleep_timer_dialog.dart';
import '../widgets/waveform_progress.dart';

/// Full-screen music player with album art, controls, queue, and sleep timer.
///
/// Features hero animation from MiniPlayer, real-time progress updates,
/// shuffle/repeat controls, and expandable queue view.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin {
  final AudioPlayerService _audioService = AudioPlayerService.instance;
  bool _showQueue = false;
  bool _showRemainingTime = false;

  late final AnimationController _rotationController;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _playerStateSubscription = _audioService.playerStateStream.listen((state) {
      if (state.playing) {
        if (!_rotationController.isAnimating) {
          _rotationController.repeat();
        }
      } else {
        _rotationController.stop();
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  Future<String?> _getThumbnailPath(Track? track) async {
    if (track?.thumbnailPath == null) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final fullPath = '${appDir.path}/${track!.thumbnailPath}';
    final file = File(fullPath);

    if (await file.exists()) {
      return fullPath;
    }
    return null;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const SleepTimerDialog(),
    );
  }

  void _showPlaybackSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlaybackSpeedDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // App bar with close button and actions
            _buildAppBar(),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Album art with hero animation
                      _buildAlbumArt(),

                      const SizedBox(height: 40),

                      // Track info
                      _buildTrackInfo(),

                      const SizedBox(height: 32),

                      // Progress bar
                      _buildProgressBar(),

                      const SizedBox(height: 24),

                      // Playback controls
                      _buildControls(),

                      const SizedBox(height: 32),

                      // Extra actions (shuffle, repeat, sleep timer, queue)
                      _buildExtraActions(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Expandable queue section
            _buildQueueSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.keyboard_arrow_down),
            color: AppColors.textSecondary,
            iconSize: 32,
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildAlbumArt() {
    return StreamBuilder<int>(
      stream: _audioService.currentIndexStream,
      initialData: _audioService.currentIndex,
      builder: (context, indexSnapshot) {
        return StreamBuilder<List<Track>>(
          stream: _audioService.queueStream,
          initialData: _audioService.queue,
          builder: (context, queueSnapshot) {
            final queue = queueSnapshot.data ?? [];
            final currentIndex = indexSnapshot.data ?? -1;
            final track = currentIndex >= 0 && currentIndex < queue.length
                ? queue[currentIndex]
                : _audioService.currentTrackInQueue;

            return FutureBuilder<String?>(
              future: _getThumbnailPath(track),
              builder: (context, snapshot) {
                final thumbnailPath = snapshot.data;

                return Hero(
                  tag: 'album_art',
                  child: RotationTransition(
                    turns: _rotationController,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.75,
                      height: MediaQuery.of(context).size.width * 0.75,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.bubbly,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          thumbnailPath != null
                              ? Image.file(
                                  File(thumbnailPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildPlaceholder();
                                  },
                                )
                              : _buildPlaceholder(),
                          // Center hole for vinyl look
                          Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.background,
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(Icons.music_note, color: AppColors.primary, size: 80),
    );
  }

  Widget _buildTrackInfo() {
    return StreamBuilder<int>(
      stream: _audioService.currentIndexStream,
      initialData: _audioService.currentIndex,
      builder: (context, indexSnapshot) {
        return StreamBuilder<List<Track>>(
          stream: _audioService.queueStream,
          initialData: _audioService.queue,
          builder: (context, queueSnapshot) {
            final queue = queueSnapshot.data ?? [];
            final currentIndex = indexSnapshot.data ?? -1;
            final track = currentIndex >= 0 && currentIndex < queue.length
                ? queue[currentIndex]
                : _audioService.currentTrackInQueue;

            return Column(
              children: [
                Text(
                  track?.title ??
                      _formatTrackName(
                        _audioService.currentTrack?.fileName ?? 'Unknown',
                      ),
                  style: AppTypography.heading2.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  track?.author ?? 'Unknown Artist',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Track info (bitrate, format, file size)
                if (track != null) _buildTrackInfoRow(track),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTrackInfoRow(Track track) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (track.bitrateKbps != null)
            _buildInfoChip(
              icon: Icons.high_quality,
              text: '${track.bitrateKbps} kbps',
            ),
          if (track.container != null) ...[
            const SizedBox(width: 12),
            _buildInfoChip(
              icon: Icons.audio_file,
              text: track.container!.toUpperCase(),
            ),
          ],
          if (track.fileSize != null) ...[
            const SizedBox(width: 12),
            _buildInfoChip(icon: Icons.storage, text: track.formattedFileSize),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: _audioService.positionStream,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration?>(
          stream: _audioService.durationStream,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;

            return Column(
              children: [
                // Waveform progress bar
                Builder(
                  builder: (context) {
                    final track = _audioService.currentTrack;

                    // Get waveform data
                    if (track != null) {
                      // Use filePath as unique ID for waveform
                      final waveformId = track.filePath.hashCode.toString();

                      return FutureBuilder<WaveformData>(
                        future: WaveformService.instance.getWaveform(
                          waveformId,
                          audioPath: track.filePath,
                          duration: duration,
                        ),
                        builder: (context, waveformSnapshot) {
                          final waveformData = waveformSnapshot.requireData;
                          return WaveformProgressBar(
                            amplitudes: waveformData.downsampleForDisplay(
                              targetBars: 100,
                            ),
                            duration: duration,
                            position: position,
                            accentColor: CurrentColor.instance.accentColor,
                            onSeek: (seekPosition) {
                              _audioService.seek(seekPosition);
                            },
                            height: 56,
                          );
                        },
                      );
                    }

                    // No track - show default
                    return WaveformProgressBar(
                      amplitudes: WaveformService.generateDefaultWaveform(
                        bars: 100,
                      ),
                      duration: duration,
                      position: position,
                      accentColor: CurrentColor.instance.accentColor,
                      onSeek: (seekPosition) {
                        _audioService.seek(seekPosition);
                      },
                      height: 56,
                    );
                  },
                ),

                const SizedBox(height: 8),

                // Time indicators
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showRemainingTime = !_showRemainingTime;
                          });
                        },
                        child: Text(
                          _showRemainingTime
                              ? '-${_formatDuration(duration - position)}'
                              : _formatDuration(duration),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildControls() {
    return StreamBuilder<PlayerState>(
      stream: _audioService.playerStateStream,
      builder: (context, stateSnapshot) {
        final isPlaying = stateSnapshot.data?.playing ?? false;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous button
            _buildControlButton(
              icon: Icons.skip_previous,
              onPressed: () => _audioService.previous(),
              size: 36,
            ),

            const SizedBox(width: 24),

            // Play/Pause button
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: AppShadows.elevated,
              ),
              child: IconButton(
                onPressed: () => _audioService.togglePlayPause(),
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),

            const SizedBox(width: 24),

            // Next button
            _buildControlButton(
              icon: Icons.skip_next,
              onPressed: () => _audioService.next(),
              size: 36,
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 24,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: AppColors.textPrimary),
      iconSize: size,
      padding: const EdgeInsets.all(12),
    );
  }

  Widget _buildExtraActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle button
        StreamBuilder<bool>(
          stream: _audioService.shuffleStream,
          initialData: _audioService.isShuffleEnabled,
          builder: (context, snapshot) {
            final isShuffleEnabled = snapshot.data ?? false;
            return _buildActionButton(
              icon: Icons.shuffle,
              onPressed: () => _audioService.toggleShuffle(),
              isActive: isShuffleEnabled,
            );
          },
        ),

        // Repeat button
        StreamBuilder<RepeatMode>(
          stream: _audioService.repeatModeStream,
          initialData: _audioService.repeatMode,
          builder: (context, snapshot) {
            final repeatMode = snapshot.data ?? RepeatMode.all;
            IconData icon;
            switch (repeatMode) {
              case RepeatMode.one:
                icon = Icons.repeat_one;
                break;
              case RepeatMode.all:
              case RepeatMode.off:
                icon = Icons.repeat;
                break;
            }

            return _buildActionButton(
              icon: icon,
              onPressed: () => _audioService.toggleRepeatMode(),
              isActive: repeatMode != RepeatMode.off,
            );
          },
        ),

        // Playback speed button
        StreamBuilder<double>(
          stream: _audioService.speedStream,
          initialData: _audioService.playbackSpeed,
          builder: (context, snapshot) {
            final speed = snapshot.data ?? 1.0;
            final isNotNormal = speed != 1.0;
            return _buildActionButton(
              icon: Icons.speed,
              onPressed: _showPlaybackSpeedDialog,
              isActive: isNotNormal,
            );
          },
        ),

        // Sleep timer button
        _buildActionButton(
          icon: Icons.timer_outlined,
          onPressed: _showSleepTimerDialog,
          isActive: false,
        ),

        // Queue button
        _buildActionButton(
          icon: Icons.queue_music,
          onPressed: () {
            setState(() {
              _showQueue = !_showQueue;
            });
          },
          isActive: _showQueue,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: isActive ? AppColors.primary : AppColors.textSecondary,
        ),
        iconSize: 24,
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildQueueSection() {
    return StreamBuilder<List<Track>>(
      stream: _audioService.queueStream,
      initialData: _audioService.queue,
      builder: (context, queueSnapshot) {
        final queue = queueSnapshot.data ?? [];

        if (queue.isEmpty) {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _showQueue ? 300 : 60,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: AppShadows.navigation,
          ),
          child: Column(
            children: [
              // Header with drag handle
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showQueue = !_showQueue;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Text(
                              'Up Next',
                              style: AppTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${queue.length} tracks',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Icon(
                              _showQueue
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Queue list
              if (_showQueue)
                Expanded(
                  child: StreamBuilder<int>(
                    stream: _audioService.currentIndexStream,
                    initialData: _audioService.currentIndex,
                    builder: (context, indexSnapshot) {
                      final currentIndex = indexSnapshot.data ?? -1;

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: queue.length,
                        itemBuilder: (context, index) {
                          final track = queue[index];
                          final isCurrentTrack = index == currentIndex;

                          return _buildQueueItem(
                            track: track,
                            index: index,
                            isCurrentTrack: isCurrentTrack,
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQueueItem({
    required Track track,
    required int index,
    required bool isCurrentTrack,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isCurrentTrack
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.divider,
          borderRadius: AppRadius.medium,
        ),
        child: Center(
          child: isCurrentTrack
              ? Icon(Icons.equalizer, color: AppColors.primary, size: 24)
              : Text(
                  '${index + 1}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
        ),
      ),
      title: Text(
        track.title,
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
          color: isCurrentTrack ? AppColors.primary : AppColors.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        track.author,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isCurrentTrack
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: () {
        if (!isCurrentTrack) {
          _audioService.skipToQueueIndex(index);
        }
      },
    );
  }

  String _formatTrackName(String name) {
    final lastDot = name.lastIndexOf('.');
    if (lastDot > 0) {
      name = name.substring(0, lastDot);
    }
    return name.replaceAll('_', ' ');
  }

  List<Track> get queue => _audioService.queue;
}
