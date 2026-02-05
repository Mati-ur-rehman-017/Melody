import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';

class AudioFileTile extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final bool isCurrentTrack;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const AudioFileTile({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.isCurrentTrack,
    required this.onTap,
    required this.onDelete,
  });

  /// Get the full path to the thumbnail file
  Future<String?> _getThumbnailPath() async {
    if (track.thumbnailPath == null) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final fullPath = '${appDir.path}/${track.thumbnailPath}';
    final file = File(fullPath);

    if (await file.exists()) {
      return fullPath;
    }
    return null;
  }

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
              // Thumbnail or play/pause indicator
              _buildThumbnail(context, colorScheme),
              const SizedBox(width: 12),

              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: isCurrentTrack ? FontWeight.bold : null,
                        color: isCurrentTrack
                            ? colorScheme.onPrimaryContainer
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.author,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isCurrentTrack
                            ? colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.8,
                              )
                            : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          track.formattedDuration,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isCurrentTrack
                                    ? colorScheme.onPrimaryContainer.withValues(
                                        alpha: 0.7,
                                      )
                                    : Colors.grey[500],
                              ),
                        ),
                        if (track.bitrateKbps != null) ...[
                          Text(
                            ' · ${track.bitrateKbps} kbps',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isCurrentTrack
                                      ? colorScheme.onPrimaryContainer
                                            .withValues(alpha: 0.7)
                                      : Colors.grey[500],
                                ),
                          ),
                        ],
                      ],
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

  Widget _buildThumbnail(BuildContext context, ColorScheme colorScheme) {
    return FutureBuilder<String?>(
      future: _getThumbnailPath(),
      builder: (context, snapshot) {
        final thumbnailPath = snapshot.data;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Thumbnail image or placeholder
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isCurrentTrack
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
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
            ),

            // Play/pause overlay when current track
            if (isCurrentTrack)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPlaceholderIcon(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.music_note,
        color: isCurrentTrack
            ? colorScheme.onPrimary
            : colorScheme.onSurfaceVariant,
        size: 28,
      ),
    );
  }
}
