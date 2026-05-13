import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/audio_visualizer.dart';

final Logger _log = Logger('SongsPage');

class SongsPage extends StatefulWidget {
  const SongsPage({super.key});

  @override
  State<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends State<SongsPage>
    with AutomaticKeepAliveClientMixin {
  final _audioService = AudioPlayerService.instance;
  final _dbService = DatabaseService.instance;

  List<Track> _allTracks = [];
  List<Track> _filteredTracks = [];
  bool _isLoadingTracks = true;
  String? _tracksErrorMessage;
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<void>? _tracksChangedSubscription;

  @override
  void initState() {
    super.initState();
    _loadTracks();

    _tracksChangedSubscription = _dbService.tracksChanged.listen((_) {
      _loadTracks();
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tracksChangedSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTracks = List.from(_allTracks);
      } else {
        _filteredTracks = _allTracks.where((track) {
          return track.title.toLowerCase().contains(query) ||
              track.author.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadTracks() async {
    _log.info('Loading tracks from database...');

    setState(() {
      _isLoadingTracks = true;
      _tracksErrorMessage = null;
    });

    try {
      final tracks = await _dbService.getAllTracks();
      _log.info('Loaded ${tracks.length} tracks from database');

      setState(() {
        _allTracks = tracks;
        _onSearchChanged();
        _isLoadingTracks = false;
      });
    } catch (e, stackTrace) {
      _log.severe('Failed to load tracks: $e');
      _log.severe('Stack trace: $stackTrace');
      setState(() {
        _tracksErrorMessage = 'Failed to load library: $e';
        _isLoadingTracks = false;
      });
    }
  }

  Future<String> _getFullPath(Track track) async {
    return DatabaseService.getAudioFilePath(
      track.filePath.replaceFirst('audio/', ''),
    );
  }

  Future<String?> _getThumbnailFullPath(Track track) async {
    if (track.thumbnailPath == null) return null;
    return DatabaseService.getThumbnailFilePath(
      track.thumbnailPath!.replaceFirst('thumbnails/', ''),
    );
  }

  Future<void> _playTrack(Track track) async {
    try {
      final trackIndex = _filteredTracks.indexWhere((t) => t.id == track.id);
      if (trackIndex == -1) {
        _log.warning('Track not found in filtered list: ${track.id}');
        return;
      }

      await _audioService.playQueue(_filteredTracks, startIndex: trackIndex);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing track: $e')));
      }
    }
  }

  Future<void> _deleteTrack(Track track) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Track'),
        content: Text('Are you sure you want to delete "${track.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final fullPath = await _getFullPath(track);

      if (_audioService.isCurrentTrack(fullPath)) {
        await _audioService.stop();
      }

      final fileToDelete = File(fullPath);
      if (await fileToDelete.exists()) {
        await fileToDelete.delete();
        _log.info('Deleted audio file: $fullPath');
      }

      final thumbnailPath = await _getThumbnailFullPath(track);
      if (thumbnailPath != null) {
        final thumbnailFile = File(thumbnailPath);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
          _log.info('Deleted thumbnail: $thumbnailPath');
        }
      }

      await _dbService.deleteTrack(track.id);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Track deleted')));
      }
    } catch (e) {
      _log.severe('Error deleting track: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting track: $e')));
      }
    }
  }

  bool _isCurrentTrack(Track track) {
    return _audioService.isCurrentQueueTrack(track);
  }

  Future<void> _showAddToPlaylistDialog(Track track) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddToPlaylistDialog(trackId: track.id),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Playlist updated')));
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Library',
                        style: AppTypography.displayMedium.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'All your downloaded songs',
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);

    if (_isLoadingTracks) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tracksErrorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              _tracksErrorMessage!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadTracks,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_allTracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.circular,
                  boxShadow: AppShadows.bubbly,
                ),
                child: TextField(
                  controller: _searchController,
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search songs...',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),

          if (_allTracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Featured Tracks',
                    style: AppTypography.heading3.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Row(
                      children: [
                        Text(
                          'View all',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_allTracks.isEmpty)
            _buildEmptySongsState()
          else
            _buildFeaturedTracksList(),
        ],
      ),
    );
  }

  Widget _buildEmptySongsState() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No downloads yet',
              style: AppTypography.heading3.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download some audio to see it here',
              style: AppTypography.bodyMedium.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedTracksList() {
    return StreamBuilder<PlayerState>(
      stream: _audioService.playerStateStream,
      builder: (context, snapshot) {
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: _filteredTracks.length,
          itemBuilder: (context, index) {
            final track = _filteredTracks[index];

            final isCurrentTrack = _isCurrentTrack(track);
            final isPlaying = isCurrentTrack && _audioService.isPlaying;

            return _buildTrackCard(
              track: track,
              isPlaying: isPlaying,
              isCurrentTrack: isCurrentTrack,
            );
          },
        );
      },
    );
  }

  Widget _buildTrackCard({
    required Track track,
    required bool isPlaying,
    required bool isCurrentTrack,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.large,
        boxShadow: AppShadows.bubbly,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.large,
        child: InkWell(
          borderRadius: AppRadius.large,
          onTap: () => _playTrack(track),
          child: Row(
            children: [
              if (isCurrentTrack)
                Container(
                  width: 4,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      FutureBuilder<String?>(
                        future: _getThumbnailFullPath(track),
                        builder: (context, snapshot) {
                          final thumbnailPath = snapshot.data;

                          return Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.medium,
                              color: AppColors.secondary.withValues(alpha: 0.1),
                            ),
                            child: ClipRRect(
                              borderRadius: AppRadius.medium,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  thumbnailPath != null
                                      ? Image.file(
                                          File(thumbnailPath),
                                          fit: BoxFit.cover,
                                          width: 64,
                                          height: 64,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.music_note,
                                                  color: AppColors.secondary,
                                                  size: 32,
                                                );
                                              },
                                        )
                                      : Icon(
                                          Icons.music_note,
                                          color: AppColors.secondary,
                                          size: 32,
                                        ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    track.title,
                                    style: AppTypography.labelLarge.copyWith(
                                      color: isCurrentTrack
                                          ? AppColors.primary
                                          : theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isPlaying) ...[
                                  const SizedBox(width: 8),
                                  const AudioVisualizer(),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${track.author} • ${track.formattedDuration}',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'add_to_playlist') {
                            _showAddToPlaylistDialog(track);
                          } else if (value == 'delete') {
                            _deleteTrack(track);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'add_to_playlist',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.playlist_add,
                                  color: theme.colorScheme.onSurface,
                                ),
                                const SizedBox(width: 8),
                                Text('Add to Playlist'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
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
  }
}
