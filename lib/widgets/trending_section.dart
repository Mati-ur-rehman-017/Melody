import 'dart:io';

import 'package:flutter/material.dart';

import '../models/trending_song.dart';
import '../theme/app_theme.dart';

/// Horizontal scrolling section for trending/viral songs
///
/// Features:
/// - Horizontal scroll with snap behavior
/// - Skeleton loading cards
/// - Error and offline states
/// - Tap to search
class TrendingSection extends StatelessWidget {
  final String title;
  final List<TrendingSong> songs;
  final bool isLoading;
  final bool isError;
  final bool isOffline;
  final VoidCallback? onRetry;
  final Function(TrendingSong) onSongTap;
  final DateTime? lastUpdated;

  const TrendingSection({
    super.key,
    required this.title,
    required this.songs,
    this.isLoading = false,
    this.isError = false,
    this.isOffline = false,
    this.onRetry,
    required this.onSongTap,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.heading2.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isOffline && lastUpdated != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last updated ${_formatTimeAgo(lastUpdated!)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
              if (isError && onRetry != null)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
            ],
          ),
        ),

        // Content based on state
        if (isLoading)
          _buildSkeletonList()
        else if (isError && songs.isEmpty)
          _buildErrorState(theme)
        else
          _buildSongList(theme),
      ],
    );
  }

  /// Build horizontal scrolling list of songs
  Widget _buildSongList(ThemeData theme) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          return _SongCard(
            song: songs[index],
            onTap: () => onSongTap(songs[index]),
          );
        },
      ),
    );
  }

  /// Build skeleton loading cards
  Widget _buildSkeletonList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: 5,
        itemBuilder: (context, index) {
          return const _SkeletonCard();
        },
      ),
    );
  }

  /// Build error state when no songs available
  Widget _buildErrorState(ThemeData theme) {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.large,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Check your internet connection',
              style: AppTypography.bodyMedium.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Connect to internet for recommendations',
              style: AppTypography.bodySmall.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Individual song card
class _SongCard extends StatelessWidget {
  final TrendingSong song;
  final VoidCallback onTap;

  const _SongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: AppRadius.large,
                boxShadow: AppShadows.card,
              ),
              child: ClipRRect(
                borderRadius: AppRadius.large,
                child: _buildThumbnail(),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              song.title,
              style: AppTypography.labelMedium.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Artist
            Text(
              song.artist,
              style: AppTypography.bodySmall.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    // Check if we have a local cached thumbnail
    if (song.thumbnailPath != null && song.thumbnailPath!.isNotEmpty) {
      final file = File(song.thumbnailPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    }

    // Try network image
    if (song.thumbnailUrl.isNotEmpty) {
      return Image.network(
        song.thumbnailUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    // Fallback placeholder
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.secondary.withOpacity(0.1),
      child: Center(
        child: Icon(Icons.music_note, color: AppColors.secondary, size: 40),
      ),
    );
  }
}

/// Skeleton loading card
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skeleton thumbnail
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: AppRadius.large,
            ),
          ),
          const SizedBox(height: 8),
          // Skeleton title
          Container(
            width: 120,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          // Skeleton artist
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
