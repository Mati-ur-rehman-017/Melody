import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Logger instance for the download service
final Logger _log = Logger('YouTubeDownloadService');

/// Video metadata information
class VideoInfo {
  final String videoId;
  final String title;
  final String author;
  final Duration? duration;

  const VideoInfo({
    required this.videoId,
    required this.title,
    required this.author,
    this.duration,
  });

  String get formattedDuration {
    if (duration == null) return 'Unknown';

    final hours = duration!.inHours;
    final minutes = duration!.inMinutes.remainder(60);
    final seconds = duration!.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Download progress information
class DownloadProgress {
  final int bytesDownloaded;
  final int totalBytes;

  const DownloadProgress({
    required this.bytesDownloaded,
    required this.totalBytes,
  });

  double get percentage =>
      totalBytes > 0 ? (bytesDownloaded / totalBytes) * 100 : 0;

  String get formattedProgress =>
      '${_formatFileSize(bytesDownloaded)} / ${_formatFileSize(totalBytes)}';
}

/// Result of a download operation
class DownloadResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;

  const DownloadResult.success(this.filePath)
    : success = true,
      errorMessage = null;

  const DownloadResult.failure(this.errorMessage)
    : success = false,
      filePath = null;
}

/// Service for downloading audio from YouTube videos
class YouTubeDownloadService {
  YoutubeExplode? _yt;

  /// YouTube API client combinations to try in order of preference
  static final List<List<YoutubeApiClient>> _clientCombinations = [
    [YoutubeApiClient.safari, YoutubeApiClient.androidVr],
    [YoutubeApiClient.android],
    [YoutubeApiClient.ios],
    [YoutubeApiClient.tv],
    [YoutubeApiClient.mediaConnect],
    [],
  ];

  /// Get the downloads directory path
  static Future<Directory> getDownloadsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${appDir.path}/downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }

  /// Initialize the YouTube client
  void _ensureClient() {
    _yt ??= YoutubeExplode();
  }

  /// Dispose of resources
  void dispose() {
    _yt?.close();
    _yt = null;
  }

  /// Extract video ID from various YouTube URL formats
  ///
  /// Returns `null` if the URL is invalid or video ID cannot be extracted.
  String? extractVideoId(String url) {
    _log.fine('Validating URL format...');

    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      _log.fine('Failed to parse URL as URI: $e');
      return null;
    }

    // Check for standard youtube.com format
    if (uri.host.contains('youtube.com')) {
      final videoId = uri.queryParameters['v'];
      if (videoId != null && videoId.isNotEmpty) {
        return _validateVideoId(videoId);
      }

      // Check for /embed/ or /v/ format
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2) {
        if (pathSegments[0] == 'embed' || pathSegments[0] == 'v') {
          return _validateVideoId(pathSegments[1]);
        }
      }
    }

    // Check for youtu.be short format
    if (uri.host == 'youtu.be') {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        return _validateVideoId(pathSegments[0]);
      }
    }

    // Try direct video ID (11 characters)
    if (_isValidVideoId(url)) {
      return url;
    }

    _log.fine('Could not extract video ID from URL');
    return null;
  }

  /// Fetch video information
  Future<VideoInfo> getVideoInfo(String videoId) async {
    _ensureClient();
    _log.info('Fetching video metadata for: $videoId');

    try {
      final video = await _yt!.videos.get(videoId);

      _log.fine('Video metadata received: ${video.title}');
      return VideoInfo(
        videoId: videoId,
        title: video.title,
        author: video.author,
        duration: video.duration,
      );
    } catch (e) {
      _log.severe('Failed to fetch video metadata: $e');
      if (e.toString().contains('Video is unavailable')) {
        throw Exception(
          'Video is unavailable. It may be private, deleted, or region-restricted.',
        );
      }
      rethrow;
    }
  }

  /// Download audio from a YouTube video
  ///
  /// [videoId] - The YouTube video ID
  /// [onProgress] - Optional callback for download progress updates
  Future<DownloadResult> downloadAudio(
    String videoId, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    _ensureClient();
    _log.info('Starting audio download for: $videoId');

    try {
      // Get stream manifest
      final (manifest, clientName) = await _tryGetManifestWithClients(videoId);
      _log.fine('Got manifest via client(s): $clientName');

      // Get audio streams
      final audioStreams = manifest.audioOnly.toList();
      _log.info('Found ${audioStreams.length} audio streams');

      if (audioStreams.isEmpty) {
        return const DownloadResult.failure(
          'No audio streams available for this video',
        );
      }

      // Select highest bitrate
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      _log.info(
        'Selected stream: ${streamInfo.container.name} @ ${streamInfo.bitrate.kiloBitsPerSecond.toStringAsFixed(0)} kbps',
      );

      // Get video title for filename
      final video = await _yt!.videos.get(videoId);
      final sanitizedTitle = _sanitizeFilename(video.title);

      // Get downloads directory
      final downloadsDir = await getDownloadsDirectory();

      // Prepare file path
      final filePath =
          '${downloadsDir.path}/$sanitizedTitle.${streamInfo.container.name}';
      final file = File(filePath);
      _log.info('Output file: $filePath');

      // Download the stream
      final totalBytes = streamInfo.size.totalBytes;
      var downloadedBytes = 0;

      final stream = _yt!.videos.streams.get(streamInfo);
      final fileStream = file.openWrite();

      try {
        await for (final chunk in stream) {
          fileStream.add(chunk);
          downloadedBytes += chunk.length;

          onProgress?.call(
            DownloadProgress(
              bytesDownloaded: downloadedBytes,
              totalBytes: totalBytes,
            ),
          );
        }

        await fileStream.flush();
        await fileStream.close();

        _log.info('Download complete: $filePath');
        return DownloadResult.success(filePath);
      } catch (e) {
        await fileStream.close();
        // Clean up partial file
        if (await file.exists()) {
          await file.delete();
        }
        rethrow;
      }
    } catch (e) {
      _log.severe('Download failed: $e');
      return DownloadResult.failure(e.toString());
    }
  }

  /// Try multiple YouTube API clients to get stream manifest
  Future<(StreamManifest, String)> _tryGetManifestWithClients(
    String videoId,
  ) async {
    final errors = <String, String>{};

    for (var i = 0; i < _clientCombinations.length; i++) {
      final clients = _clientCombinations[i];
      final clientNames = clients.isEmpty
          ? 'default'
          : clients.map((c) => c.toString().split('.').last).join(', ');

      _log.fine('Attempt ${i + 1}/${_clientCombinations.length}: $clientNames');

      try {
        final StreamManifest manifest;
        if (clients.isEmpty) {
          manifest = await _yt!.videos.streams.getManifest(videoId);
        } else {
          manifest = await _yt!.videos.streams.getManifest(
            videoId,
            ytClients: clients,
          );
        }

        _log.info('Success with client(s): $clientNames');
        return (manifest, clientNames);
      } catch (e) {
        final errorMsg = e.toString();
        errors[clientNames] = errorMsg;

        if (errorMsg.contains('403') || errorMsg.contains('Forbidden')) {
          _log.warning('[$clientNames] returned 403, trying next...');
          continue;
        }

        if (errorMsg.contains('sign') || errorMsg.contains('cipher')) {
          _log.warning('[$clientNames] signature error, trying next...');
          continue;
        }

        _log.warning('[$clientNames] failed: $errorMsg');
      }
    }

    throw Exception(
      'Failed to get stream manifest after trying ${_clientCombinations.length} client combinations. '
      'The video may be geo-restricted, age-restricted, or require authentication.',
    );
  }

  /// Validate video ID format
  String? _validateVideoId(String videoId) {
    return _isValidVideoId(videoId) ? videoId : null;
  }

  /// Check if string is a valid YouTube video ID
  bool _isValidVideoId(String id) {
    final regex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    return regex.hasMatch(id);
  }

  /// Sanitize filename by removing invalid characters
  String _sanitizeFilename(String filename) {
    var sanitized = filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();

    if (sanitized.length > 200) {
      sanitized = sanitized.substring(0, 200);
    }

    sanitized = sanitized.replaceAll(RegExp(r'^_+|_+$'), '');
    return sanitized;
  }
}

/// Format file size for display
String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
