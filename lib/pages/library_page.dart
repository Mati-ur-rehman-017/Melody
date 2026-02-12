import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import '../constants.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/create_playlist_dialog.dart';
import 'playlist_detail_page.dart';

final Logger _log = Logger('LibraryPage');

/// Library page with Melody Bubbly aesthetic
///
/// Features header, pill tabs, featured tracks, and jump back in section
/// while maintaining full playlist and track management functionality.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _audioService = AudioPlayerService.instance;
  final _dbService = DatabaseService.instance;

  // Tab selection
  String _activeTab = 'songs';

  // Songs tab state
  List<Track> _allTracks = [];
  List<Track> _filteredTracks = [];
  bool _isLoadingTracks = true;
  String? _tracksErrorMessage;
  final TextEditingController _searchController = TextEditingController();

  // Playlists tab state
  List<Playlist> _playlists = [];
  bool _isLoadingPlaylists = true;
  String? _playlistsErrorMessage;

  StreamSubscription<void>? _tracksChangedSubscription;

  @override
  void initState() {
    super.initState();
    _loadTracks();
    _loadPlaylists();

    // Subscribe to track changes
    _tracksChangedSubscription = _dbService.tracksChanged.listen((_) {
      _loadTracks();
      _loadPlaylists();
    });

    // Listen to search input
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
        _onSearchChanged(); // Apply current filter
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

  Future<void> _loadPlaylists() async {
    _log.info('Loading playlists from database...');

    setState(() {
      _isLoadingPlaylists = true;
      _playlistsErrorMessage = null;
    });

    try {
      final playlists = await _dbService.getAllPlaylists();
      _log.info('Loaded ${playlists.length} playlists from database');

      // Verify track counts by loading actual tracks for each playlist
      final verifiedPlaylists = <Playlist>[];
      for (final playlist in playlists) {
        final tracks = await _dbService.getPlaylistTracks(playlist.id);
        verifiedPlaylists.add(playlist.copyWith(trackCount: tracks.length));
      }

      setState(() {
        _playlists = verifiedPlaylists;
        _isLoadingPlaylists = false;
      });
    } catch (e, stackTrace) {
      _log.severe('Failed to load playlists: $e');
      _log.severe('Stack trace: $stackTrace');
      setState(() {
        _playlistsErrorMessage = 'Failed to load playlists: $e';
        _isLoadingPlaylists = false;
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
      // Find the index of the tapped track in the filtered list
      final trackIndex = _filteredTracks.indexWhere((t) => t.id == track.id);
      if (trackIndex == -1) {
        _log.warning('Track not found in filtered list: ${track.id}');
        return;
      }

      // Play the queue starting from the tapped track
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

  Future<void> _createPlaylist() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const CreatePlaylistDialog(),
    );

    if (name != null && name.isNotEmpty) {
      try {
        await _dbService.createPlaylist(name);
        await _loadPlaylists();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Playlist created')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating playlist: $e')),
          );
        }
      }
    }
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"?\n\nThis will not delete the songs from your library.',
        ),
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
      await _dbService.deletePlaylist(playlist.id);
      await _loadPlaylists();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Playlist deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting playlist: $e')));
      }
    }
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailPage(playlist: playlist),
      ),
    ).then((_) => _loadPlaylists()); // Refresh when returning
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
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),

                // Pill tabs
                _buildPillTabs(),

                // Content based on active tab
                Expanded(
                  child: _activeTab == 'songs'
                      ? _buildSongsTab()
                      : _buildPlaylistsTab(),
                ),
              ],
            ),

            // FAB - positioned dynamically based on mini player visibility
            StreamBuilder<PlayerState>(
              stream: _audioService.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final isPlayerVisible =
                    playerState?.processingState != ProcessingState.idle &&
                    _audioService.currentTrack != null;

                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  right: 24,
                  bottom: isPlayerVisible ? 150 : 90,
                  child: FloatingActionButton(
                    onPressed: _activeTab == 'songs' ? null : _createPlaylist,
                    backgroundColor: AppColors.primary,
                    elevation: 4,
                    child: const Icon(Icons.add, size: 32),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build header with title
  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title
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
                'Your favorite sounds',
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build pill-style tabs
  Widget _buildPillTabs() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.circular,
        ),
        child: Row(
          children: [
            // All Songs tab
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = 'songs'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _activeTab == 'songs'
                        ? theme.colorScheme.surfaceContainerHighest
                        : Colors.transparent,
                    borderRadius: AppRadius.circular,
                    boxShadow: _activeTab == 'songs' ? AppShadows.card : null,
                  ),
                  child: Text(
                    'All Songs',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelLarge.copyWith(
                      color: _activeTab == 'songs'
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: _activeTab == 'songs'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),

            // Playlists tab
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = 'playlists'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _activeTab == 'playlists'
                        ? theme.colorScheme.surfaceContainerHighest
                        : Colors.transparent,
                    borderRadius: AppRadius.circular,
                    boxShadow: _activeTab == 'playlists'
                        ? AppShadows.card
                        : null,
                  ),
                  child: Text(
                    'Playlists',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelLarge.copyWith(
                      color: _activeTab == 'playlists'
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: _activeTab == 'playlists'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build songs tab with featured tracks and jump back in
  Widget _buildSongsTab() {
    final theme = Theme.of(context);

    if (_isLoadingTracks) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tracksErrorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.primary),
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
          // Search bar
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
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
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

          // Featured tracks header
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
                        const Icon(
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

          // Featured tracks list or empty state
          if (_allTracks.isEmpty)
            _buildEmptySongsState()
          else
            _buildFeaturedTracksList(),
        ],
      ),
    );
  }

  /// Build empty songs state
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
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No downloads yet',
              style: AppTypography.heading3.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download some audio to see it here',
              style: AppTypography.bodyMedium.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build featured tracks list with rounded card tiles
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

  /// Build individual track card
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
              // Left accent bar for currently playing track
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
                      // Album art with thumbnail
                      FutureBuilder<String?>(
                        future: _getThumbnailFullPath(track),
                        builder: (context, snapshot) {
                          final thumbnailPath = snapshot.data;

                          return Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.medium,
                              color: AppColors.secondary.withOpacity(0.1),
                            ),
                            child: ClipRRect(
                              borderRadius: AppRadius.medium,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Thumbnail image or placeholder
                                  thumbnailPath != null
                                      ? Image.file(
                                          File(thumbnailPath),
                                          fit: BoxFit.cover,
                                          width: 64,
                                          height: 64,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return const Icon(
                                                  Icons.music_note,
                                                  color: AppColors.secondary,
                                                  size: 32,
                                                );
                                              },
                                        )
                                      : const Icon(
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

                      // Track info
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
                                // Sound wave animation for playing track
                                if (isPlaying) ...[
                                  const SizedBox(width: 8),
                                  const _AudioVisualizer(),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${track.author} • ${track.formattedDuration}',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // More options
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
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

  /// Build jump back in section
  Widget _buildJumpBackInSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Text(
            'Jump Back In',
            style: AppTypography.heading3.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),

        // Horizontal scroll
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: AppConstants.jumpBackIn.length,
            itemBuilder: (context, index) {
              final playlist = AppConstants.jumpBackIn[index];
              return _buildJumpBackInCard(playlist);
            },
          ),
        ),
      ],
    );
  }

  /// Build jump back in card
  Widget _buildJumpBackInCard(PlaylistPreview playlist) {
    final theme = Theme.of(context);

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Playlist image
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Color(playlist.backgroundColor),
              borderRadius: AppRadius.large,
              boxShadow: AppShadows.bubbly,
            ),
            padding: const EdgeInsets.all(8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: AppRadius.medium,
              ),
              child: const Center(
                child: Icon(
                  Icons.queue_music,
                  color: AppColors.secondary,
                  size: 48,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Playlist name
          Text(
            playlist.name,
            style: AppTypography.labelLarge.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build playlists tab
  Widget _buildPlaylistsTab() {
    final theme = Theme.of(context);

    if (_isLoadingPlaylists) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_playlistsErrorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              _playlistsErrorMessage!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPlaylists,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No playlists yet',
              style: AppTypography.heading3.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a playlist to organize your songs',
              style: AppTypography.bodyMedium.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlaylists,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          final playlist = _playlists[index];

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
                onTap: () => _openPlaylist(playlist),
                onLongPress: () => _deletePlaylist(playlist),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Playlist icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: AppRadius.medium,
                        ),
                        child: const Icon(
                          Icons.queue_music,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Playlist info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playlist.name,
                              style: AppTypography.labelLarge.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${playlist.trackCount ?? 0} songs',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Arrow
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Audio visualizer widget with animated bars for currently playing track
class _AudioVisualizer extends StatefulWidget {
  const _AudioVisualizer();

  @override
  State<_AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<_AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBar(0.3, 0.7),
            const SizedBox(width: 2),
            _buildBar(0.5, 0.9),
            const SizedBox(width: 2),
            _buildBar(0.4, 0.8),
            const SizedBox(width: 2),
            _buildBar(0.6, 1.0),
          ],
        );
      },
    );
  }

  Widget _buildBar(double minHeight, double maxHeight) {
    final animationValue = _controller.value;
    final height =
        minHeight +
        (maxHeight - minHeight) *
            (0.5 + 0.5 * sin(animationValue * 2 * pi * 2 + minHeight * 10));

    return Container(
      width: 3,
      height: 16 * height,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
