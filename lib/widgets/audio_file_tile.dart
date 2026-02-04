import 'package:flutter/material.dart';

import '../pages/library_page.dart';

/// Format duration as mm:ss or hh:mm:ss
String formatDuration(Duration? duration) {
  if (duration == null) return '--:--';

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class AudioFileTile extends StatelessWidget {
  final AudioFile file;
  final bool isPlaying;
  final bool isCurrentTrack;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const AudioFileTile({
    super.key,
    required this.file,
    required this.isPlaying,
    required this.isCurrentTrack,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isCurrentTrack ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Play/Pause indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCurrentTrack
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: isCurrentTrack
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),

              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatFileName(file.name),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: isCurrentTrack ? FontWeight.bold : null,
                        color: isCurrentTrack
                            ? colorScheme.onPrimaryContainer
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDuration(file.duration),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isCurrentTrack
                            ? colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.7,
                              )
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: isCurrentTrack
                      ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                      : Colors.grey[600],
                ),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format the filename for display (remove extension, replace underscores)
  String _formatFileName(String name) {
    // Remove file extension
    final lastDot = name.lastIndexOf('.');
    if (lastDot > 0) {
      name = name.substring(0, lastDot);
    }

    // Replace underscores with spaces for readability
    return name.replaceAll('_', ' ');
  }
}
