import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../models/download_task.dart';
import 'database_service.dart';
import 'youtube_download_service.dart';

final Logger _log = Logger('DownloadManagerService');

class DownloadManagerService extends ChangeNotifier {
  static final DownloadManagerService _instance =
      DownloadManagerService._internal();
  static DownloadManagerService get instance => _instance;

  DownloadManagerService._internal();

  final _dbService = DatabaseService.instance;
  final _downloadService = YouTubeDownloadService();

  List<DownloadTask> _tasks = [];
  bool _initialized = false;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  List<DownloadTask> get activeTasks =>
      _tasks.where((t) => t.status == DownloadStatus.downloading).toList();

  List<DownloadTask> get pendingTasks =>
      _tasks.where((t) => t.status == DownloadStatus.pending).toList();

  List<DownloadTask> get failedTasks =>
      _tasks.where((t) => t.status == DownloadStatus.failed).toList();

  List<DownloadTask> get completedTasks =>
      _tasks.where((t) => t.status == DownloadStatus.completed).toList();

  bool get hasActiveDownloads =>
      _tasks.any((t) => t.status == DownloadStatus.downloading);

  Future<void> initialize() async {
    if (_initialized) return;
    _log.info('Initializing DownloadManagerService');
    await _loadTasks();
    _initialized = true;
  }

  Future<void> _loadTasks() async {
    try {
      _tasks = await _dbService.getAllDownloadTasks();
      _log.info('Loaded ${_tasks.length} download tasks');
    } catch (e) {
      _log.warning('Failed to load download tasks: $e');
      _tasks = [];
    }
  }

  Future<void> addDownload({
    required String videoId,
    required String title,
    required String author,
    String? thumbnailUrl,
  }) async {
    if (_tasks.any((t) => t.videoId == videoId)) {
      _log.fine('Download already tracked: $videoId');
      return;
    }

    final task = DownloadTask(
      videoId: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
    );

    _tasks.insert(0, task);
    await _dbService.insertDownloadTask(task);
    notifyListeners();

    _startDownload(task);
  }

  Future<void> _startDownload(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    task.progress = 0.0;
    task.errorMessage = null;
    task.userFacingMessage = null;
    await _dbService.updateDownloadTask(task);
    notifyListeners();

    try {
      final result = await _downloadService.downloadAudio(
        task.videoId,
        onProgress: (progress) {
          task.progress = progress.percentage / 100;
          notifyListeners();
        },
      );

      // Persist progress periodically (last update)
      await _dbService.updateDownloadTask(task);

      if (result.success) {
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        task.completedAt = DateTime.now();
        task.errorMessage = null;
        task.userFacingMessage = null;
        await _dbService.updateDownloadTask(task);
        _log.info('Download completed: ${task.title}');
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage = result.errorMessage;
        task.userFacingMessage = _userFacingError(result.errorMessage ?? '');
        task.retryCount++;
        task.completedAt = DateTime.now();
        await _dbService.updateDownloadTask(task);
        _log.warning(
          'Download failed: ${task.title} — ${task.userFacingMessage}',
        );
      }
    } catch (e) {
      _log.severe('Download error: $e');
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      task.userFacingMessage = _userFacingError(e.toString());
      task.retryCount++;
      task.completedAt = DateTime.now();
      await _dbService.updateDownloadTask(task);
    }

    notifyListeners();
  }

  Future<void> retryDownload(String videoId) async {
    final task = _tasks.where((t) => t.videoId == videoId).firstOrNull;
    if (task == null) return;
    if (task.status != DownloadStatus.failed) return;

    _startDownload(task);
  }

  Future<void> removeTask(String videoId) async {
    _tasks.removeWhere((t) => t.videoId == videoId);
    await _dbService.deleteDownloadTask(videoId);
    notifyListeners();
  }

  Future<void> clearCompleted() async {
    _tasks.removeWhere((t) => t.status == DownloadStatus.completed);
    await _dbService.clearCompletedDownloadTasks();
    notifyListeners();
  }

  String _userFacingError(String raw) {
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'Network error. Check your internet connection.';
    }
    if (raw.contains('403') || raw.contains('Forbidden')) {
      return 'This video is restricted and cannot be downloaded.';
    }
    if (raw.contains('sign') || raw.contains('cipher')) {
      return 'Could not process the audio stream for this video.';
    }
    if (raw.contains('Video is unavailable') ||
        raw.contains('private') ||
        raw.contains('deleted')) {
      return 'Video unavailable — it may be private, deleted, or region-restricted.';
    }
    if (raw.contains('No audio streams')) {
      return 'No downloadable audio found for this video.';
    }
    if (raw.contains('already in your library')) {
      return 'Already in your library.';
    }
    if (raw.contains('getManifest') || raw.contains('client')) {
      return 'Download unavailable. This video may require authentication.';
    }
    return 'Download failed. Please try again.';
  }

  @override
  void dispose() {
    _downloadService.dispose();
    super.dispose();
  }
}
