import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import '../models/playlist.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/database_service.dart';
import '../widgets/add_songs_to_playlist_dialog.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/audio_file_tile.dart';
import '../widgets/mini_player.dart';

final Logger _log = Logger('PlaylistDetailPage');

class PlaylistDetailPage extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final _audioService = AudioPlayerService.instance;
  final _dbService = DatabaseService.instance;

  List<Track> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;
  late Playlist _currentPlaylist;

  StreamSubscription<void>? _tracksChangedSubscription;

  @override
  void initState() {
    super.initState();
    _currentPlaylist = widget.playlist;
    _loadTracks();
    _loadPlaylistInfo();

    // Subscribe to track changes
    _tracksChangedSubscription = _dbService.tracksChanged.listen((_) {
      _loadTracks();
    });
  }

  @override
  void dispose() {
    _tracksChangedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPlaylistInfo() async {
    try {
      final playlist = await _dbService.getPlaylistById(widget.playlist.id);
      if (playlist != null && mounted) {
        setState(() {
          _currentPlaylist = playlist;
        });
      }
    } catch (e) {
      _log.warning('Failed to load playlist info: $e');
    }
  }

  Future<void> _loadTracks() async {
    _log.info('Loading tracks for playlist: ${widget.playlist.id}');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tracks = await _dbService.getPlaylistTracks(widget.playlist.id);
      _log.info('Loaded ${tracks.length} tracks from playlist');

      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });
      }

      // Refresh playlist info to update track count
      await _loadPlaylistInfo();
    } catch (e, stackTrace) {
      _log.severe('Failed to load playlist tracks: $e');
      _log.severe('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load tracks: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _playTrack(Track track) async {
    try {
      // Find the index of the tapped track in the playlist
      final trackIndex = _tracks.indexWhere((t) => t.id == track.id);
      if (trackIndex == -1) {
        _log.warning('Track not found in playlist: ${track.id}');
        return;
      }

      // Play the playlist queue starting from the tapped track
      await _audioService.playQueue(_tracks, startIndex: trackIndex);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing track: $e')));
      }
    }
  }

  Future<void> _removeTrackFromPlaylist(Track track) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Playlist'),
        content: Text('Remove "${track.title}" from this playlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _dbService.removeTrackFromPlaylist(widget.playlist.id, track.id);

      await _loadTracks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Track removed from playlist')),
        );
      }
    } catch (e) {
      _log.severe('Error removing track from playlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      await _loadTracks();
    }
  }

  Future<void> _showAddSongsDialog() async {
    final addedCount = await showDialog<int>(
      context: context,
      builder: (context) =>
          AddSongsToPlaylistDialog(playlistId: widget.playlist.id),
    );

    if (addedCount != null && addedCount > 0 && mounted) {
      await _loadTracks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added $addedCount ${addedCount == 1 ? 'song' : 'songs'} to playlist',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackCount = _currentPlaylist.trackCount ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentPlaylist.name),
            Text(
              '$trackCount ${trackCount == 1 ? 'song' : 'songs'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _showAddSongsDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Songs'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main content
          Expanded(child: _buildBody()),
          // Mini player (shows when audio is playing)
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
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

    if (_tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No songs in this playlist',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Add songs from your library',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTracks,
      child: StreamBuilder<PlayerState>(
        stream: _audioService.playerStateStream,
        builder: (context, snapshot) {
          return ListView.builder(
            itemCount: _tracks.length,
            itemBuilder: (context, index) {
              final track = _tracks[index];

              final isCurrentTrack = _isCurrentTrack(track);
              final isPlaying = isCurrentTrack && _audioService.isPlaying;

              return Dismissible(
                key: Key('${widget.playlist.id}_${track.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Remove from Playlist'),
                      content: Text(
                        'Remove "${track.title}" from this playlist?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  _removeTrackFromPlaylist(track);
                },
                child: AudioFileTile(
                  track: track,
                  isPlaying: isPlaying,
                  isCurrentTrack: isCurrentTrack,
                  onTap: () => _playTrack(track),
                  onDelete: () => _removeTrackFromPlaylist(track),
                  onAddToPlaylist: () => _showAddToPlaylistDialog(track),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
