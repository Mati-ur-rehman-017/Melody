import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import '../models/track.dart';
import 'database_service.dart';

/// Logger instance for the audio player service
final Logger _log = Logger('AudioPlayerService');

/// Repeat mode for queue playback
enum RepeatMode { off, all, one }

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

/// Singleton service for audio playback with queue support
class AudioPlayerService {
  AudioPlayerService._internal() {
    _init();
  }

  static final AudioPlayerService instance = AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();

  // Queue management
  List<Track> _queue = [];
  int _currentIndex = -1;
  RepeatMode _repeatMode = RepeatMode.all;

  // Track info for display
  TrackInfo? _currentTrack;

  // Stream controllers
  final StreamController<RepeatMode> _repeatModeController =
      StreamController<RepeatMode>.broadcast();
  final StreamController<List<Track>> _queueController =
      StreamController<List<Track>>.broadcast();
  final StreamController<int> _currentIndexController =
      StreamController<int>.broadcast();

  /// Currently playing track info
  TrackInfo? get currentTrack => _currentTrack;

  /// Current playback queue
  List<Track> get queue => List.unmodifiable(_queue);

  /// Current position in queue (-1 if no queue)
  int get currentIndex => _currentIndex;

  /// Current repeat mode
  RepeatMode get repeatMode => _repeatMode;

  /// Currently playing track from queue (null if no queue)
  Track? get currentTrackInQueue {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      return _queue[_currentIndex];
    }
    return null;
  }

  /// Whether there is a next track in queue
  bool get hasNext =>
      _queue.isNotEmpty &&
      (_currentIndex < _queue.length - 1 || _repeatMode != RepeatMode.off);

  /// Whether there is a previous track in queue
  bool get hasPrevious =>
      _queue.isNotEmpty && (_currentIndex > 0 || _repeatMode != RepeatMode.off);

  /// Stream of player state changes
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Stream of position changes
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of duration changes
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Stream of repeat mode changes
  Stream<RepeatMode> get repeatModeStream => _repeatModeController.stream;

  /// Stream of queue changes
  Stream<List<Track>> get queueStream => _queueController.stream;

  /// Stream of current index changes
  Stream<int> get currentIndexStream => _currentIndexController.stream;

  /// Current playback position
  Duration get position => _player.position;

  /// Current track duration
  Duration? get duration => _player.duration;

  /// Whether audio is currently playing
  bool get isPlaying => _player.playing;

  /// Current player state
  PlayerState get playerState => _player.playerState;

  void _init() {
    // Listen for completion to auto-advance queue
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _log.fine('Playback completed');
        _handleTrackCompletion();
      }
    });
  }

  /// Handle track completion based on repeat mode
  void _handleTrackCompletion() {
    _log.fine('Handling track completion, repeat mode: $_repeatMode');

    switch (_repeatMode) {
      case RepeatMode.one:
        // Repeat current track
        _log.info('Repeating current track');
        _player.seek(Duration.zero);
        _player.play();
        break;
      case RepeatMode.all:
      case RepeatMode.off:
        // Try to go to next track
        if (_currentIndex < _queue.length - 1) {
          // More tracks in queue
          _log.info('Advancing to next track');
          next();
        } else if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
          // At end, loop back to start
          _log.info('Looping back to first track');
          _playQueueIndex(0);
        } else {
          // At end, no repeat
          _log.info('End of queue, stopping');
          stop();
        }
        break;
    }
  }

  /// Play a queue of tracks starting at the specified index
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    _log.info(
      'Setting up queue with ${tracks.length} tracks, starting at index $startIndex',
    );

    if (tracks.isEmpty) {
      _log.warning('Cannot play empty queue');
      return;
    }

    if (startIndex < 0 || startIndex >= tracks.length) {
      _log.warning('Invalid start index: $startIndex, using 0');
      startIndex = 0;
    }

    _queue = List.from(tracks);
    _queueController.add(_queue);

    await _playQueueIndex(startIndex);
  }

  /// Play the track at the specified queue index
  Future<void> _playQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length) {
      _log.warning('Invalid queue index: $index');
      return;
    }

    _currentIndex = index;
    _currentIndexController.add(_currentIndex);

    final track = _queue[index];
    final fullPath = await DatabaseService.getAudioFilePath(
      track.filePath.replaceFirst('audio/', ''),
    );

    await _playFile(fullPath);
  }

  /// Play a single audio file (internal)
  Future<void> _playFile(String filePath) async {
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

  /// Play an audio file (for backward compatibility)
  Future<void> play(String filePath) async {
    // Clear queue when playing a single file
    _queue = [];
    _currentIndex = -1;
    _queueController.add(_queue);
    _currentIndexController.add(_currentIndex);

    await _playFile(filePath);
  }

  /// Go to next track in queue (circular)
  Future<void> next() async {
    if (_queue.isEmpty) {
      _log.warning('No queue set, cannot go to next');
      return;
    }

    int nextIndex = _currentIndex + 1;

    // Circular navigation
    if (nextIndex >= _queue.length) {
      nextIndex = 0;
    }

    _log.info('Going to next track, index: $nextIndex');
    await _playQueueIndex(nextIndex);
  }

  /// Go to previous track in queue (circular)
  Future<void> previous() async {
    if (_queue.isEmpty) {
      _log.warning('No queue set, cannot go to previous');
      return;
    }

    int prevIndex = _currentIndex - 1;

    // Circular navigation
    if (prevIndex < 0) {
      prevIndex = _queue.length - 1;
    }

    _log.info('Going to previous track, index: $prevIndex');
    await _playQueueIndex(prevIndex);
  }

  /// Set repeat mode
  void setRepeatMode(RepeatMode mode) {
    _log.info('Setting repeat mode to: $mode');
    _repeatMode = mode;
    _repeatModeController.add(_repeatMode);
  }

  /// Toggle repeat mode (all -> one -> all)
  void toggleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.all:
        setRepeatMode(RepeatMode.one);
        break;
      case RepeatMode.one:
        setRepeatMode(RepeatMode.all);
        break;
      case RepeatMode.off:
        // Shouldn't happen with default, but handle it
        setRepeatMode(RepeatMode.all);
        break;
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

  /// Check if a specific track is currently playing in queue
  bool isCurrentQueueTrack(Track track) {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) {
      return false;
    }
    return _queue[_currentIndex].id == track.id;
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
    await _repeatModeController.close();
    await _queueController.close();
    await _currentIndexController.close();
    await _player.dispose();
  }
}
