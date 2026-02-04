import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/youtube_download_service.dart';

/// Download state enum
enum DownloadState {
  idle,
  validating,
  fetchingInfo,
  downloading,
  complete,
  error,
}

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final _urlController = TextEditingController();
  final _downloadService = YouTubeDownloadService();

  DownloadState _state = DownloadState.idle;
  VideoInfo? _videoInfo;
  DownloadProgress? _progress;
  String? _errorMessage;
  String? _savedFilePath;

  @override
  void dispose() {
    _urlController.dispose();
    _downloadService.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
    }
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _state = DownloadState.error;
        _errorMessage = 'Please enter a YouTube URL';
      });
      return;
    }

    // Reset state
    setState(() {
      _state = DownloadState.validating;
      _videoInfo = null;
      _progress = null;
      _errorMessage = null;
      _savedFilePath = null;
    });

    // Extract video ID
    final videoId = _downloadService.extractVideoId(url);
    if (videoId == null) {
      setState(() {
        _state = DownloadState.error;
        _errorMessage = 'Invalid YouTube URL. Please check and try again.';
      });
      return;
    }

    // Fetch video info
    setState(() => _state = DownloadState.fetchingInfo);

    try {
      final info = await _downloadService.getVideoInfo(videoId);
      setState(() => _videoInfo = info);
    } catch (e) {
      setState(() {
        _state = DownloadState.error;
        _errorMessage = 'Failed to fetch video info: $e';
      });
      return;
    }

    // Start download
    setState(() => _state = DownloadState.downloading);

    final result = await _downloadService.downloadAudio(
      videoId,
      onProgress: (progress) {
        setState(() => _progress = progress);
      },
    );

    if (result.success) {
      setState(() {
        _state = DownloadState.complete;
        _savedFilePath = result.filePath;
      });
    } else {
      setState(() {
        _state = DownloadState.error;
        _errorMessage = result.errorMessage ?? 'Download failed';
      });
    }
  }

  void _reset() {
    setState(() {
      _state = DownloadState.idle;
      _videoInfo = null;
      _progress = null;
      _errorMessage = null;
      _savedFilePath = null;
      _urlController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing =
        _state == DownloadState.validating ||
        _state == DownloadState.fetchingInfo ||
        _state == DownloadState.downloading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // URL Input
          TextField(
            controller: _urlController,
            enabled: !isProcessing,
            decoration: InputDecoration(
              labelText: 'YouTube URL',
              hintText: 'https://youtube.com/watch?v=...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                tooltip: 'Paste from clipboard',
                onPressed: isProcessing ? null : _pasteFromClipboard,
              ),
            ),
            keyboardType: TextInputType.url,
            onSubmitted: isProcessing ? null : (_) => _startDownload(),
          ),

          const SizedBox(height: 16),

          // Download Button
          ElevatedButton.icon(
            onPressed: isProcessing ? null : _startDownload,
            icon: const Icon(Icons.download),
            label: const Text('Download Audio'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          const SizedBox(height: 24),

          // Status Section
          _buildStatusSection(),

          // Video Info Card
          if (_videoInfo != null) ...[
            const SizedBox(height: 16),
            _buildVideoInfoCard(),
          ],

          // Progress Section
          if (_state == DownloadState.downloading && _progress != null) ...[
            const SizedBox(height: 16),
            _buildProgressSection(),
          ],

          // Success Section
          if (_state == DownloadState.complete) ...[
            const SizedBox(height: 16),
            _buildSuccessSection(),
          ],

          // Error Section
          if (_state == DownloadState.error) ...[
            const SizedBox(height: 16),
            _buildErrorSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    String statusText;
    IconData statusIcon;
    Color? statusColor;

    switch (_state) {
      case DownloadState.idle:
        statusText = 'Enter a YouTube URL to download audio';
        statusIcon = Icons.info_outline;
        statusColor = Colors.grey;
      case DownloadState.validating:
        statusText = 'Validating URL...';
        statusIcon = Icons.hourglass_empty;
        statusColor = Colors.blue;
      case DownloadState.fetchingInfo:
        statusText = 'Fetching video information...';
        statusIcon = Icons.cloud_download;
        statusColor = Colors.blue;
      case DownloadState.downloading:
        statusText = 'Downloading audio...';
        statusIcon = Icons.downloading;
        statusColor = Colors.blue;
      case DownloadState.complete:
        statusText = 'Download complete!';
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
      case DownloadState.error:
        statusText = 'Error occurred';
        statusIcon = Icons.error;
        statusColor = Colors.red;
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            statusText,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
          ),
        ),
        if (_state == DownloadState.validating ||
            _state == DownloadState.fetchingInfo)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildVideoInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _videoInfo!.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _videoInfo!.author,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.timer, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _videoInfo!.formattedDuration,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final percentage = _progress!.percentage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: percentage / 100, minHeight: 8),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _progress!.formattedProgress,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessSection() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Download Complete!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Saved to:',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(_savedFilePath ?? '', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Download Another'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSection() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text(
                  'Error',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              style: TextStyle(color: Colors.red[900]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
