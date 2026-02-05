import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/database_service.dart';
import '../widgets/audio_file_tile.dart';

/// Logger instance for the library page
final Logger _log = Logger('LibraryPage');

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _audioService = AudioPlayerService.instance;
  final _dbService = DatabaseService.instance;

  List<Track> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription<void>? _tracksChangedSubscription;

  @override
  void initState() {
    super.initState();
    _loadTracks();

    // Subscribe to track changes to auto-refresh when downloads complete
    _tracksChangedSubscription = _dbService.tracksChanged.listen((_) {
      _loadTracks();
    });
  }

  @override
  void dispose() {
    _tracksChangedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    _log.info('Loading tracks from database...');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tracks = await _dbService.getAllTracks();
      _log.info('Loaded ${tracks.length} tracks from database');

      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      _log.severe('Failed to load tracks: $e');
      _log.severe('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Failed to load library: $e';
        _isLoading = false;
      });
    }
  }

  /// Get the full file path for a track
  Future<String> _getFullPath(Track track) async {
    return DatabaseService.getAudioFilePath(
      track.filePath.replaceFirst('audio/', ''),
    );
  }

  /// Get the full file path for a track's thumbnail
  Future<String?> _getThumbnailFullPath(Track track) async {
    if (track.thumbnailPath == null) return null;
    return DatabaseService.getThumbnailFilePath(
      track.thumbnailPath!.replaceFirst('thumbnails/', ''),
    );
  }

  Future<void> _playTrack(Track track) async {
    try {
      final fullPath = await _getFullPath(track);

      if (_audioService.isCurrentTrack(fullPath)) {
        // Toggle play/pause if same track
        await _audioService.togglePlayPause();
      } else {
        // Play new track
        await _audioService.play(fullPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing track: $e')));
      }
    }
  }

  Future<void> _deleteTrack(Track track) async {
    // Show confirmation dialog
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

      // Stop playback if this track is currently playing
      if (_audioService.isCurrentTrack(fullPath)) {
        await _audioService.stop();
      }

      // Delete the audio file
      final fileToDelete = File(fullPath);
      if (await fileToDelete.exists()) {
        await fileToDelete.delete();
        _log.info('Deleted audio file: $fullPath');
      }

      // Delete the thumbnail file if it exists
      final thumbnailPath = await _getThumbnailFullPath(track);
      if (thumbnailPath != null) {
        final thumbnailFile = File(thumbnailPath);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
          _log.info('Deleted thumbnail: $thumbnailPath');
        }
      }

      // Remove from database
      await _dbService.deleteTrack(track.id);

      // Reload the track list
      await _loadTracks();

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

  /// Check if a track is currently loaded (need to resolve full path)
  Future<bool> _isCurrentTrack(Track track) async {
    final fullPath = await _getFullPath(track);
    return _audioService.isCurrentTrack(fullPath);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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

    return RefreshIndicator(
      onRefresh: _loadTracks,
      child: StreamBuilder<PlayerState>(
        stream: _audioService.playerStateStream,
        builder: (context, snapshot) {
          return ListView.builder(
            itemCount: _tracks.length,
            itemBuilder: (context, index) {
              final track = _tracks[index];

              // Use FutureBuilder to resolve full path for comparison
              return FutureBuilder<bool>(
                future: _isCurrentTrack(track),
                builder: (context, isCurrentSnapshot) {
                  final isCurrentTrack = isCurrentSnapshot.data ?? false;
                  final isPlaying = isCurrentTrack && _audioService.isPlaying;

                  return AudioFileTile(
                    track: track,
                    isPlaying: isPlaying,
                    isCurrentTrack: isCurrentTrack,
                    onTap: () => _playTrack(track),
                    onDelete: () => _deleteTrack(track),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
