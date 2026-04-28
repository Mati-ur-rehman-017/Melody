import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Format view count in abbreviated form (e.g., 1.2M views)
String _formatViewCount(int views) {
  if (views >= 1000000000) {
    return '${(views / 1000000000).toStringAsFixed(1)}B views';
  } else if (views >= 1000000) {
    return '${(views / 1000000).toStringAsFixed(1)}M views';
  } else if (views >= 1000) {
    return '${(views / 1000).toStringAsFixed(1)}K views';
  }
  return '$views views';
}

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

/// Widget for displaying a YouTube search result
class SearchResultTile extends StatelessWidget {
  /// The video search result from youtube_explode_dart
  final Video video;

  /// Whether this video is already downloaded in the library
  final bool isDownloaded;

  /// Whether this video is currently being downloaded
  final bool isDownloading;

  /// Download progress (0.0 to 1.0), only used when isDownloading is true
  final double? downloadProgress;

  /// Callback when download button is pressed
  final VoidCallback? onDownload;

  /// Whether this video is currently streaming (playing in local preview player)
  final bool isStreaming;

  /// Whether the stream URL is currently loading
  final bool isStreamLoading;

  /// Callback when stream button is toggled
  final VoidCallback? onStreamToggle;

  const SearchResultTile({
    super.key,
    required this.video,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress,
    this.onDownload,
    this.isStreaming = false,
    this.isStreamLoading = false,
    this.onStreamToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with duration badge
            _buildThumbnail(context),
            const SizedBox(width: 12),

            // Video info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    video.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Author
                  Text(
                    video.author,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Views and duration
                  Text(
                    '${_formatViewCount(video.engagement.viewCount)} · ${_formatDuration(video.duration)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            // Download button / indicator
            _buildDownloadAction(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return Stack(
      children: [
        // Thumbnail image
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            video.thumbnails.mediumResUrl,
            width: 120,
            height: 68,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 120,
                height: 68,
                color: Colors.grey[300],
                child: const Icon(Icons.error_outline, color: Colors.grey),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 120,
                height: 68,
                color: Colors.grey[200],
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          ),
        ),

        // Stream play/pause overlay
        if (onStreamToggle != null)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onStreamToggle,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: isStreaming || isStreamLoading ? 0.5 : 0.2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isStreamLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(
                            isStreaming
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 32,
                          ),
                  ),
                ),
              ),
            ),
          ),

        // Duration badge
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatDuration(video.duration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadAction(ColorScheme colorScheme) {
    // Already downloaded - show checkmark
    if (isDownloaded) {
      return Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Icon(Icons.check_circle, color: Colors.green[600], size: 28),
      );
    }

    // Currently downloading - show progress
    if (isDownloading) {
      return Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: downloadProgress,
                strokeWidth: 3,
                backgroundColor: Colors.grey[300],
                color: Colors.green,
              ),
              if (downloadProgress != null)
                Text(
                  '${(downloadProgress! * 100).toInt()}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Not downloaded - show download button
    return IconButton(
      onPressed: onDownload,
      icon: Icon(Icons.download, color: colorScheme.primary),
      tooltip: 'Download',
    );
  }
}
