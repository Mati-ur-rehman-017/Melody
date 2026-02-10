import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import '../services/audio_player_service.dart';

/// A mini player widget that shows at the bottom when audio is playing
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
        final colorScheme = Theme.of(context).colorScheme;

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Progress bar only
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
                      minHeight: 2,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    );
                  },
                ),

                // Row 2: Artwork, Track info, Controls
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Artwork thumbnail
                      FutureBuilder<String?>(
                        future: _getThumbnailPath(track),
                        builder: (context, snapshot) {
                          final thumbnailPath = snapshot.data;

                          return Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: thumbnailPath != null
                                ? Image.file(
                                    File(thumbnailPath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildPlaceholderIcon(colorScheme);
                                    },
                                  )
                                : _buildPlaceholderIcon(colorScheme),
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
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track?.author ?? 'Unknown Artist',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
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
                                ? colorScheme.onSurface
                                : Colors.grey[400],
                            iconSize: 28,
                            padding: EdgeInsets.zero,
                            tooltip: 'Previous',
                          );
                        },
                      ),

                      // Play/Pause button
                      IconButton(
                        onPressed: () => audioService.togglePlayPause(),
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 40,
                        ),
                        color: colorScheme.primary,
                        padding: EdgeInsets.zero,
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
                                ? colorScheme.onSurface
                                : Colors.grey[400],
                            iconSize: 28,
                            padding: EdgeInsets.zero,
                            tooltip: 'Next',
                          );
                        },
                      ),

                      // Repeat mode button
                      StreamBuilder<RepeatMode>(
                        stream: audioService.repeatModeStream,
                        initialData: audioService.repeatMode,
                        builder: (context, modeSnapshot) {
                          final mode = modeSnapshot.data ?? RepeatMode.all;

                          IconData icon;
                          String tooltip;

                          switch (mode) {
                            case RepeatMode.all:
                              icon = Icons.repeat;
                              tooltip = 'Repeat All';
                              break;
                            case RepeatMode.one:
                              icon = Icons.repeat_one;
                              tooltip = 'Repeat One';
                              break;
                            case RepeatMode.off:
                              icon = Icons.repeat;
                              tooltip = 'Repeat Off';
                              break;
                          }

                          return IconButton(
                            onPressed: () => audioService.toggleRepeatMode(),
                            icon: Icon(icon),
                            color: mode == RepeatMode.off
                                ? Colors.grey[400]
                                : colorScheme.primary,
                            iconSize: 24,
                            padding: const EdgeInsets.all(4),
                            tooltip: tooltip,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderIcon(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.music_note,
        color: colorScheme.onPrimaryContainer,
        size: 24,
      ),
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
