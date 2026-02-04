import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import '../services/audio_player_service.dart';
import '../services/youtube_download_service.dart';
import '../widgets/audio_file_tile.dart';

/// Logger instance for the library page
final Logger _log = Logger('LibraryPage');

/// Information about a downloaded audio file
class AudioFile {
  final String path;
  final String name;
  final Duration? duration;

  const AudioFile({required this.path, required this.name, this.duration});
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _audioService = AudioPlayerService.instance;

  List<AudioFile> _files = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    _log.info('Starting to load files...');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _log.fine('Getting downloads directory...');
      final downloadsDir = await YouTubeDownloadService.getDownloadsDirectory();
      _log.fine('Downloads directory: ${downloadsDir.path}');

      final files = <AudioFile>[];

      if (await downloadsDir.exists()) {
        _log.fine('Directory exists, listing files...');
        final entities = downloadsDir.listSync();
        _log.info('Found ${entities.length} entities in downloads directory');

        // PHASE 1: Quickly collect all files WITHOUT loading durations
        for (final entity in entities) {
          if (entity is File) {
            final path = entity.path;
            final name = path.split('/').last;
            _log.fine('Found file: $name');

            // Add file with null duration initially
            files.add(AudioFile(path: path, name: name, duration: null));
          }
        }
      } else {
        _log.warning('Downloads directory does not exist');
      }

      // Sort by name
      files.sort((a, b) => a.name.compareTo(b.name));
      _log.info('Phase 1 complete: ${files.length} files ready to display');

      // Show the list immediately (Phase 1 complete)
      setState(() {
        _files = files;
        _isLoading = false;
      });

      // PHASE 2: Load durations in background and update progressively
      if (files.isNotEmpty) {
        _log.info('Phase 2: Loading durations for ${files.length} files...');
        _loadDurationsInBackground();
      }
    } catch (e, stackTrace) {
      _log.severe('Failed to load files: $e');
      _log.severe('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Failed to load files: $e';
        _isLoading = false;
      });
    }
  }

  /// Load durations for all files in the background
  /// Updates the UI progressively as each duration is fetched
  Future<void> _loadDurationsInBackground() async {
    for (var i = 0; i < _files.length; i++) {
      final file = _files[i];

      // Skip if duration already loaded
      if (file.duration != null) continue;

      _log.fine('Loading duration ${i + 1}/${_files.length}: ${file.name}');

      try {
        final duration = await _audioService.getFileDuration(file.path);

        // Update the file with its duration
        if (mounted) {
          setState(() {
            _files[i] = AudioFile(
              path: file.path,
              name: file.name,
              duration: duration,
            );
          });
          _log.fine('Duration loaded for ${file.name}: $duration');
        }
      } catch (e) {
        _log.warning('Failed to load duration for ${file.name}: $e');
        // Continue to next file even if this one fails
      }
    }
    _log.info('Phase 2 complete: All durations loaded');
  }

  Future<void> _playFile(AudioFile file) async {
    try {
      if (_audioService.isCurrentTrack(file.path)) {
        // Toggle play/pause if same track
        await _audioService.togglePlayPause();
      } else {
        // Play new track
        await _audioService.play(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing file: $e')));
      }
    }
  }

  Future<void> _deleteFile(AudioFile file) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
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
      // Stop playback if this file is currently playing
      if (_audioService.isCurrentTrack(file.path)) {
        await _audioService.stop();
      }

      // Delete the file
      final fileToDelete = File(file.path);
      if (await fileToDelete.exists()) {
        await fileToDelete.delete();
      }

      // Reload the file list
      await _loadFiles();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting file: $e')));
      }
    }
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
              onPressed: _loadFiles,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
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
      onRefresh: _loadFiles,
      child: StreamBuilder<PlayerState>(
        stream: _audioService.playerStateStream,
        builder: (context, snapshot) {
          return ListView.builder(
            itemCount: _files.length,
            itemBuilder: (context, index) {
              final file = _files[index];
              final isCurrentTrack = _audioService.isCurrentTrack(file.path);
              final isPlaying = isCurrentTrack && _audioService.isPlaying;

              return AudioFileTile(
                file: file,
                isPlaying: isPlaying,
                isCurrentTrack: isCurrentTrack,
                onTap: () => _playFile(file),
                onDelete: () => _deleteFile(file),
              );
            },
          );
        },
      ),
    );
  }
}
