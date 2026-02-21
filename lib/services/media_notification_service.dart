import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import '../models/track.dart';
import 'audio_player_service.dart';
import 'database_service.dart';

final Logger _log = Logger('MediaNotificationService');

class MediaNotificationService extends BaseAudioHandler {
  final AudioPlayerService _audioPlayer = AudioPlayerService.instance;

  MediaNotificationService() {
    _init();
  }

  void _init() {
    _log.info('Initializing media notification service');

    _audioPlayer.playerStateStream.listen((state) {
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (state.playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: _mapProcessingState(state.processingState),
          playing: state.playing,
          updatePosition: _audioPlayer.position,
          bufferedPosition: _audioPlayer.position,
          speed: _audioPlayer.playbackSpeed,
        ),
      );
    });

    _audioPlayer.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    });

    _audioPlayer.playingTrackStream.listen((track) {
      if (track != null) {
        _updateMediaItem(track);
      } else {
        mediaItem.add(null);
      }
    });
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  Future<void> _updateMediaItem(Track track) async {
    _log.fine('Updating media item for: ${track.title}');

    Uri? artUri;

    if (track.thumbnailPath != null) {
      try {
        final fullPath = await DatabaseService.getThumbnailFilePath(
          track.thumbnailPath!.replaceFirst('thumbnails/', ''),
        );
        final file = File(fullPath);
        if (await file.exists()) {
          artUri = Uri.file(fullPath);
          _log.fine('Using local thumbnail URI: $artUri');
        }
      } catch (e) {
        _log.warning('Failed to load thumbnail: $e');
      }
    }

    final duration = track.duration ?? _audioPlayer.duration;

    mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.title,
        artist: track.author,
        duration: duration,
        artUri: artUri,
        playable: true,
      ),
    );
  }

  @override
  Future<void> play() async {
    _log.fine('Play command from notification');
    await _audioPlayer.resume();
  }

  @override
  Future<void> pause() async {
    _log.fine('Pause command from notification');
    await _audioPlayer.pause();
  }

  @override
  Future<void> skipToNext() async {
    _log.fine('Skip to next command from notification');
    await _audioPlayer.next();
  }

  @override
  Future<void> skipToPrevious() async {
    _log.fine('Skip to previous command from notification');
    await _audioPlayer.previous();
  }

  @override
  Future<void> seek(Duration position) async {
    _log.fine('Seek command from notification: $position');
    await _audioPlayer.seek(position);
  }

  @override
  Future<void> stop() async {
    _log.fine('Stop command from notification');
    await _audioPlayer.stop();
    await super.stop();
  }

  void updateTrack(Track track) {
    _updateMediaItem(track);
  }

  void clearNotification() {
    mediaItem.add(null);
  }
}
