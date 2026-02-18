import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import '../pages/player_page.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

/// Mini player widget with Melody Bubbly aesthetic
///
/// Shows at the bottom when audio is playing with rounded styling,
/// terracotta progress bar, and soft shadows.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

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

  @override
  Widget build(BuildContext context) {
    final audioService = AudioPlayerService.instance;

    return StreamBuilder<PlayerState>(
      stream: audioService.playerStateStream,
      builder: (context, stateSnapshot) {
        final playerState = stateSnapshot.data;
        final processingState = playerState?.processingState;
        final isPlaying = playerState?.playing ?? false;

        // Don't show if no track or if idle
        if (audioService.currentTrack == null ||
            processingState == ProcessingState.idle) {
          return const SizedBox.shrink();
        }

        final track = audioService.currentTrackInQueue;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PlayerPage(),
                fullscreenDialog: true,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: AppRadius.xLarge,
              boxShadow: AppShadows.miniPlayer,
            ),
            child: ClipRRect(
              borderRadius: AppRadius.xLarge,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar - terracotta color
                  StreamBuilder<Duration>(
                    stream: audioService.positionStream,
                    builder: (context, posSnapshot) {
                      final position = posSnapshot.data ?? Duration.zero;
                      final duration = audioService.duration ?? Duration.zero;
                      final progress = duration.inMilliseconds > 0
                          ? position.inMilliseconds / duration.inMilliseconds
                          : 0.0;

                      return LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      );
                    },
                  ),

                  // Content row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        // Artwork thumbnail with rounded corners
                        FutureBuilder<String?>(
                          future: _getThumbnailPath(track),
                          builder: (context, snapshot) {
                            final thumbnailPath = snapshot.data;

                            return Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: AppRadius.medium,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: thumbnailPath != null
                                  ? Image.file(
                                      File(thumbnailPath),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return _buildPlaceholderIcon();
                                          },
                                    )
                                  : _buildPlaceholderIcon(),
                            );
                          },
                        ),
                        const SizedBox(width: 12),

                        // Track info (expanded)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track?.title ??
                                    _formatTrackName(
                                      audioService.currentTrack!.fileName,
                                    ),
                                style: AppTypography.labelLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track?.author ?? 'Unknown Artist',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Previous button
                        StreamBuilder<List<Track>>(
                          stream: audioService.queueStream,
                          initialData: audioService.queue,
                          builder: (context, queueSnapshot) {
                            final hasQueue =
                                queueSnapshot.data?.isNotEmpty ?? false;

                            return IconButton(
                              onPressed: hasQueue
                                  ? () => audioService.previous()
                                  : null,
                              icon: const Icon(Icons.skip_previous),
                              color: hasQueue
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary.withOpacity(0.3),
                              iconSize: 24,
                              padding: EdgeInsets.zero,
                              tooltip: 'Previous',
                            );
                          },
                        ),

                        // Play/Pause button
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.elevated,
                          ),
                          child: IconButton(
                            onPressed: () => audioService.togglePlayPause(),
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),

                        // Next button
                        StreamBuilder<List<Track>>(
                          stream: audioService.queueStream,
                          initialData: audioService.queue,
                          builder: (context, queueSnapshot) {
                            final hasQueue =
                                queueSnapshot.data?.isNotEmpty ?? false;

                            return IconButton(
                              onPressed: hasQueue
                                  ? () => audioService.next()
                                  : null,
                              icon: const Icon(Icons.skip_next),
                              color: hasQueue
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary.withOpacity(0.3),
                              iconSize: 24,
                              padding: EdgeInsets.zero,
                              tooltip: 'Next',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: Icon(Icons.music_note, color: AppColors.primary, size: 24),
    );
  }

  /// Format the track name for display (fallback when Track model not available)
  String _formatTrackName(String name) {
    // Remove file extension
    final lastDot = name.lastIndexOf('.');
    if (lastDot > 0) {
      name = name.substring(0, lastDot);
    }

    // Replace underscores with spaces
    return name.replaceAll('_', ' ');
  }
}
