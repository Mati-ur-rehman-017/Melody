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

/// Sleep timer mode
enum SleepTimerMode { duration, tracks }

/// Sleep timer action
enum SleepTimerAction { pause, stop, closeApp }

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
  List<Track> _originalQueue = []; // Store original order for shuffle
  int _currentIndex = -1;
  RepeatMode _repeatMode = RepeatMode.all;
  bool _isShuffleEnabled = false;

  // Track info for display
  TrackInfo? _currentTrack;

  // Stream controllers
  final StreamController<RepeatMode> _repeatModeController =
      StreamController<RepeatMode>.broadcast();
  final StreamController<List<Track>> _queueController =
      StreamController<List<Track>>.broadcast();
  final StreamController<int> _currentIndexController =
      StreamController<int>.broadcast();
  final StreamController<bool> _shuffleController =
      StreamController<bool>.broadcast();
  final StreamController<double> _speedController =
      StreamController<double>.broadcast();
  final StreamController<Track?> _playingTrackController =
      StreamController<Track?>.broadcast();

  // Sleep timer
  Timer? _sleepTimer;
  Timer? _fadeOutTimer;
  DateTime? _sleepTimerEndTime;
  SleepTimerMode _sleepTimerMode = SleepTimerMode.duration;
  int? _sleepTimerTrackCount;
  SleepTimerAction _sleepTimerAction = SleepTimerAction.pause;

  /// Currently playing track info
  TrackInfo? get currentTrack => _currentTrack;

  /// Sleep timer end time (null if no timer set)
  DateTime? get sleepTimerEndTime => _sleepTimerEndTime;

  /// Whether shuffle is enabled
  bool get isShuffleEnabled => _isShuffleEnabled;

  /// Current playback speed
  double get playbackSpeed => _player.speed;

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

  /// Stream of shuffle state changes
  Stream<bool> get shuffleStream => _shuffleController.stream;

  /// Stream of playback speed changes
  Stream<double> get speedStream => _speedController.stream;

  /// Stream of currently playing track changes (for notification service)
  Stream<Track?> get playingTrackStream => _playingTrackController.stream;

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
        _handleTrackCompletionWithSleepTimer();
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

    _originalQueue = List.from(tracks);

    // Apply shuffle if enabled
    if (_isShuffleEnabled) {
      _queue = _shuffleList(_originalQueue, startIndex);
      // Find the new index of the starting track
      final startTrack = tracks[startIndex];
      _currentIndex = _queue.indexWhere((t) => t.id == startTrack.id);
    } else {
      _queue = List.from(tracks);
      _currentIndex = startIndex;
    }

    _queueController.add(_queue);

    await _playQueueIndex(_currentIndex);
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
    _playingTrackController.add(track);

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

  /// Skip to a specific queue index
  Future<void> skipToQueueIndex(int index) async {
    if (_queue.isEmpty) {
      _log.warning('No queue set, cannot skip');
      return;
    }

    if (index < 0 || index >= _queue.length) {
      _log.warning('Invalid queue index: $index');
      return;
    }

    _log.info('Skipping to queue index: $index');
    await _playQueueIndex(index);
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
    _playingTrackController.add(null);
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

  /// Toggle shuffle mode
  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    _log.info('Shuffle mode: $_isShuffleEnabled');

    if (_isShuffleEnabled) {
      // Store current track before shuffling
      final currentTrack = _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

      // Shuffle the queue
      _queue = _shuffleList(_queue, _currentIndex);

      // Update current index to reflect new position
      if (currentTrack != null) {
        _currentIndex = _queue.indexWhere((t) => t.id == currentTrack.id);
      }
    } else {
      // Restore original order
      final currentTrack = _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

      _queue = List.from(_originalQueue);

      // Restore current index
      if (currentTrack != null) {
        _currentIndex = _queue.indexWhere((t) => t.id == currentTrack.id);
      }
    }

    _queueController.add(_queue);
    _currentIndexController.add(_currentIndex);
    _shuffleController.add(_isShuffleEnabled);
  }

  /// Shuffle a list while keeping the item at currentIndex at position 0
  List<Track> _shuffleList(List<Track> list, int currentIndex) {
    if (list.isEmpty || list.length == 1) return List.from(list);

    final shuffled = List<Track>.from(list);
    final currentTrack = currentIndex >= 0 && currentIndex < shuffled.length
        ? shuffled.removeAt(currentIndex)
        : null;

    // Fisher-Yates shuffle
    final random = DateTime.now().millisecondsSinceEpoch;
    for (int i = shuffled.length - 1; i > 0; i--) {
      final j = (random + i * 31) % (i + 1);
      final temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }

    // Put current track at the beginning
    if (currentTrack != null) {
      shuffled.insert(0, currentTrack);
    }

    return shuffled;
  }

  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    final clampedSpeed = speed.clamp(0.5, 2.0);
    _log.info('Setting playback speed to $clampedSpeed');
    await _player.setSpeed(clampedSpeed);
    _speedController.add(clampedSpeed);
  }

  /// Set a sleep timer with advanced options
  void setSleepTimer({
    Duration? duration,
    int? trackCount,
    SleepTimerAction action = SleepTimerAction.pause,
    Duration fadeOutDuration = const Duration(seconds: 10),
  }) {
    // Cancel any existing timer
    cancelSleepTimer();

    if (duration != null) {
      _sleepTimerMode = SleepTimerMode.duration;
      _sleepTimerEndTime = DateTime.now().add(duration);
      _sleepTimerAction = action;

      _log.info('Setting sleep timer for $duration with action: $action');

      // Start fade out before timer ends
      if (fadeOutDuration < duration) {
        final fadeOutStart = duration - fadeOutDuration;
        _fadeOutTimer = Timer(fadeOutStart, () {
          _log.info('Starting fade out');
          _startFadeOut(fadeOutDuration);
        });
      }

      _sleepTimer = Timer(duration, () {
        _log.info('Sleep timer triggered - executing action: $action');
        _executeSleepTimerAction(action);
        _sleepTimerEndTime = null;
      });
    } else if (trackCount != null) {
      _sleepTimerMode = SleepTimerMode.tracks;
      _sleepTimerTrackCount = trackCount;
      _sleepTimerAction = action;
      _sleepTimerEndTime = null; // No specific end time for track-based
      _log.info('Setting sleep timer for $trackCount tracks');
    }
  }

  /// Start fading out volume
  void _startFadeOut(Duration duration) async {
    final steps = 20;
    final stepDuration = duration ~/ steps;
    final originalVolume = 1.0; // Assume full volume

    for (int i = 0; i < steps; i++) {
      if (_sleepTimer == null) break; // Timer was cancelled
      final volume = originalVolume * (1 - (i / steps));
      await _player.setVolume(volume);
      await Future.delayed(stepDuration);
    }
  }

  /// Execute the sleep timer action
  void _executeSleepTimerAction(SleepTimerAction action) {
    switch (action) {
      case SleepTimerAction.pause:
        pause();
        break;
      case SleepTimerAction.stop:
        stop();
        break;
      case SleepTimerAction.closeApp:
        pause();
        // Note: Actually closing the app requires platform-specific code
        break;
    }
    // Reset volume
    _player.setVolume(1.0);
  }

  /// Handle track completion for track-based sleep timer
  void _handleTrackCompletionWithSleepTimer() {
    if (_sleepTimerMode == SleepTimerMode.tracks &&
        _sleepTimerTrackCount != null) {
      _sleepTimerTrackCount = _sleepTimerTrackCount! - 1;
      _log.info(
        'Track-based sleep timer: $_sleepTimerTrackCount tracks remaining',
      );

      if (_sleepTimerTrackCount! <= 0) {
        _log.info('Track-based sleep timer expired');
        _executeSleepTimerAction(_sleepTimerAction);
        cancelSleepTimer();
        return;
      }
    }
    _handleTrackCompletion();
  }

  /// Cancel the active sleep timer
  void cancelSleepTimer() {
    if (_sleepTimer != null || _fadeOutTimer != null) {
      _log.info('Cancelling sleep timer');
      _sleepTimer?.cancel();
      _fadeOutTimer?.cancel();
      _sleepTimer = null;
      _fadeOutTimer = null;
      _sleepTimerEndTime = null;
      _sleepTimerTrackCount = null;
      // Reset volume
      _player.setVolume(1.0);
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    cancelSleepTimer();
    await _repeatModeController.close();
    await _queueController.close();
    await _currentIndexController.close();
    await _shuffleController.close();
    await _speedController.close();
    await _playingTrackController.close();
    await _player.dispose();
  }
}
