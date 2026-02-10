import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import '../models/playlist.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/database_service.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/audio_file_tile.dart';
import '../widgets/create_playlist_dialog.dart';
import '../widgets/playlist_list_tile.dart';
import 'playlist_detail_page.dart';

final Logger _log = Logger('LibraryPage');

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  final _audioService = AudioPlayerService.instance;
  final _dbService = DatabaseService.instance;

  late TabController _tabController;

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
    _tabController = TabController(length: 2, vsync: this);
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
    _tabController.dispose();
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

      setState(() {
        _playlists = playlists;
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.music_note), text: 'Songs'),
            Tab(icon: Icon(Icons.queue_music), text: 'Playlists'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _KeepAliveWrapper(child: _buildSongsTab()),
              _KeepAliveWrapper(child: _buildPlaylistsTab()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSongsTab() {
    if (_isLoadingTracks) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading library...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_tracksErrorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_tracksErrorMessage!, textAlign: TextAlign.center),
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

    if (_allTracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No downloads yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Download some audio to see it here',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search songs...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        // Track count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_filteredTracks.length} ${_filteredTracks.length == 1 ? 'song' : 'songs'}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ),
        ),
        // Track list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTracks,
            child: StreamBuilder<PlayerState>(
              stream: _audioService.playerStateStream,
              builder: (context, snapshot) {
                return ListView.builder(
                  itemCount: _filteredTracks.length,
                  itemBuilder: (context, index) {
                    final track = _filteredTracks[index];

                    final isCurrentTrack = _isCurrentTrack(track);
                    final isPlaying = isCurrentTrack && _audioService.isPlaying;

                    return AudioFileTile(
                      track: track,
                      isPlaying: isPlaying,
                      isCurrentTrack: isCurrentTrack,
                      onTap: () => _playTrack(track),
                      onDelete: () => _deleteTrack(track),
                      onAddToPlaylist: () => _showAddToPlaylistDialog(track),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsTab() {
    if (_isLoadingPlaylists) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_playlistsErrorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_playlistsErrorMessage!, textAlign: TextAlign.center),
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

    return Stack(
      children: [
        _playlists.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.queue_music, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No playlists yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a playlist to organize your songs',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadPlaylists,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = _playlists[index];

                    return PlaylistListTile(
                      playlist: playlist,
                      onTap: () => _openPlaylist(playlist),
                      onDelete: () => _deletePlaylist(playlist),
                    );
                  },
                ),
              ),
        // FAB for creating new playlist
        // FAB for creating new playlist
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _createPlaylist,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

/// Wrapper widget that keeps its child alive when switching tabs
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
