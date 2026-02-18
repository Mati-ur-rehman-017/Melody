import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';

/// Queue view widget showing the current playback queue
///
/// Features:
/// - List of tracks with current track highlighting
/// - Tap to jump to track
/// - Visual distinction for played tracks
class QueueView extends StatelessWidget {
  final ScrollController scrollController;

  const QueueView({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Track>>(
      stream: AudioPlayerService.instance.queueStream,
      initialData: AudioPlayerService.instance.queue,
      builder: (context, queueSnapshot) {
        final queue = queueSnapshot.data ?? [];

        if (queue.isEmpty) {
          return const Center(
            child: Text(
              'Queue is empty',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return StreamBuilder<int>(
          stream: AudioPlayerService.instance.currentIndexStream,
          initialData: AudioPlayerService.instance.currentIndex,
          builder: (context, indexSnapshot) {
            final currentIndex = indexSnapshot.data ?? -1;

            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Up Next',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '${queue.length} tracks',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  // Queue list
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final track = queue[index];
                        final isCurrentTrack = index == currentIndex;
                        final isPlayed = index < currentIndex;

                        return _QueueListTile(
                          index: index,
                          track: track,
                          isCurrentTrack: isCurrentTrack,
                          isPlayed: isPlayed,
                          onTap: () => _onTrackTap(index),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onTrackTap(int index) {
    final currentIndex = AudioPlayerService.instance.currentIndex;
    if (index != currentIndex) {
      AudioPlayerService.instance.skipToQueueIndex(index);
    }
  }
}

/// Individual queue list tile
class _QueueListTile extends StatelessWidget {
  final int index;
  final Track track;
  final bool isCurrentTrack;
  final bool isPlayed;
  final VoidCallback onTap;

  const _QueueListTile({
    required this.index,
    required this.track,
    required this.isCurrentTrack,
    required this.isPlayed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isPlayed ? 0.4 : 1.0,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCurrentTrack ? Colors.white24 : Colors.grey[800],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: isCurrentTrack
                ? const Icon(Icons.volume_up, color: Colors.white, size: 20)
                : Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
          ),
        ),
        title: Text(
          track.title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          track.author,
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isCurrentTrack
            ? Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
        onTap: onTap,
        tileColor: isCurrentTrack ? Colors.white.withOpacity(0.1) : null,
      ),
    );
  }
}
