import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/audio_player_service.dart';

/// Format duration as mm:ss or hh:mm:ss
String _formatDuration(Duration? duration) {
  if (duration == null) return '--:--';

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// A mini player widget that shows at the bottom when audio is playing
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

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

        final track = audioService.currentTrack!;
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
                // Progress bar
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

                // Player controls
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Track icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.music_note,
                          color: colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Track info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTrackName(track.fileName),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            StreamBuilder<Duration>(
                              stream: audioService.positionStream,
                              builder: (context, posSnapshot) {
                                final position =
                                    posSnapshot.data ?? Duration.zero;
                                final duration = audioService.duration;

                                return Text(
                                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // Play/Pause button
                      IconButton(
                        onPressed: () => audioService.togglePlayPause(),
                        icon: Icon(
                          isPlaying ? Icons.pause_circle : Icons.play_circle,
                          size: 40,
                        ),
                        color: colorScheme.primary,
                        padding: EdgeInsets.zero,
                      ),

                      // Stop button
                      IconButton(
                        onPressed: () => audioService.stop(),
                        icon: const Icon(Icons.stop_circle_outlined),
                        color: Colors.grey[600],
                        tooltip: 'Stop',
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

  /// Format the track name for display
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
