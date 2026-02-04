import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

/// Logger instance for the audio player service
final Logger _log = Logger('AudioPlayerService');

/// Information about the currently playing track
class TrackInfo {
  final String filePath;
  final String fileName;
  final Duration? duration;

  const TrackInfo({
    required this.filePath,
    required this.fileName,
    this.duration,
  });
}

/// Singleton service for audio playback
class AudioPlayerService {
  AudioPlayerService._internal() {
    _init();
  }

  static final AudioPlayerService instance = AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();

  TrackInfo? _currentTrack;

  /// Currently playing track info
  TrackInfo? get currentTrack => _currentTrack;

  /// Stream of player state changes
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Stream of position changes
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of duration changes
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Current playback position
  Duration get position => _player.position;

  /// Current track duration
  Duration? get duration => _player.duration;

  /// Whether audio is currently playing
  bool get isPlaying => _player.playing;

  /// Current player state
  PlayerState get playerState => _player.playerState;

  void _init() {
    // Listen for completion to clear current track
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _log.fine('Playback completed');
      }
    });
  }

  /// Play an audio file
  Future<void> play(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      final fileName = filePath.split('/').last;
      _log.info('Playing: $fileName');

      // Set the audio source
      final duration = await _player.setFilePath(filePath);

      _currentTrack = TrackInfo(
        filePath: filePath,
        fileName: fileName,
        duration: duration,
      );

      // Start playback
      await _player.play();
    } catch (e) {
      _log.severe('Error playing audio: $e');
      rethrow;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    _log.fine('Pausing playback');
    await _player.pause();
  }

  /// Resume playback
  Future<void> resume() async {
    _log.fine('Resuming playback');
    await _player.play();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  /// Stop playback and clear current track
  Future<void> stop() async {
    _log.fine('Stopping playback');
    await _player.stop();
    _currentTrack = null;
  }

  /// Seek to a specific position
  Future<void> seek(Duration position) async {
    _log.fine('Seeking to: $position');
    await _player.seek(position);
  }

  /// Check if a specific file is currently loaded
  bool isCurrentTrack(String filePath) {
    return _currentTrack?.filePath == filePath;
  }

  /// Get duration of an audio file without playing it
  ///
  /// Returns null if the file cannot be read or times out after 3 seconds.
  Future<Duration?> getFileDuration(String filePath) async {
    final fileName = filePath.split('/').last;
    _log.fine('Getting duration for: $fileName');

    try {
      // Create a temporary player to get duration
      final tempPlayer = AudioPlayer();
      try {
        // Add timeout to prevent hanging on problematic files
        final duration = await tempPlayer
            .setFilePath(filePath)
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                _log.warning('Timeout getting duration for: $fileName');
                return null;
              },
            );
        _log.fine('Got duration for $fileName: $duration');
        return duration;
      } finally {
        await tempPlayer.dispose();
      }
    } catch (e) {
      _log.warning('Could not get duration for: $fileName - $e');
      return null;
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _player.dispose();
  }
}
