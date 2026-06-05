import 'package:flutter/material.dart';

import '../models/download_task.dart';
import '../services/download_manager_service.dart';
import '../theme/app_theme.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage>
    with AutomaticKeepAliveClientMixin {
  final _manager = DownloadManagerService.instance;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onManagerChanged);
    _manager.initialize();
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _onManagerChanged() {
    if (mounted) setState(() {});
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Downloads',
                        style: AppTypography.displayMedium.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        _buildSubtitle(),
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_manager.completedTasks.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await _manager.clearCompleted();
                      },
                      child: Text(
                        'Clear completed',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final active = _manager.activeTasks.length;
    final failed = _manager.failedTasks.length;
    final parts = <String>[];
    if (active > 0) parts.add('$active downloading');
    if (failed > 0) parts.add('$failed failed');
    if (parts.isEmpty) parts.add('All caught up');
    return parts.join(' · ');
  }

  Widget _buildContent() {
    if (_manager.tasks.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_manager.activeTasks.isNotEmpty) ...[
            _buildSectionHeader('Downloading'),
            ..._manager.activeTasks.map((t) => _buildDownloadCard(t)),
          ],
          if (_manager.pendingTasks.isNotEmpty) ...[
            _buildSectionHeader('Waiting'),
            ..._manager.pendingTasks.map((t) => _buildDownloadCard(t)),
          ],
          if (_manager.failedTasks.isNotEmpty) ...[
            _buildSectionHeader('Failed'),
            ..._manager.failedTasks.map((t) => _buildDownloadCard(t)),
          ],
          if (_manager.completedTasks.isNotEmpty) ...[
            _buildSectionHeader('Completed'),
            ..._manager.completedTasks.map((t) => _buildDownloadCard(t)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No downloads yet',
              style: AppTypography.heading3.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Downloads from Search will appear here',
              style: AppTypography.bodyMedium.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: AppTypography.labelLarge.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildDownloadCard(DownloadTask task) {
    final theme = Theme.of(context);
    final isActive = task.status == DownloadStatus.downloading;
    final isPending = task.status == DownloadStatus.pending;
    final isFailed = task.status == DownloadStatus.failed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.large,
        boxShadow: AppShadows.bubbly,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.medium,
                    color: AppColors.secondary.withValues(alpha: 0.1),
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.medium,
                    child: task.thumbnailUrl != null
                        ? Image.network(
                            task.thumbnailUrl!,
                            fit: BoxFit.cover,
                            width: 48,
                            height: 48,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholderIcon(),
                          )
                        : _buildPlaceholderIcon(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: AppTypography.labelLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.author,
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusIcon(task),
              ],
            ),
            if (isActive || isPending) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: LinearProgressIndicator(
                  value: isPending ? 0.0 : task.progress,
                  minHeight: 4,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isPending ? 'Waiting...' : '${(task.progress * 100).toInt()}%',
                style: AppTypography.bodySmall.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
            if (isFailed) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: AppRadius.small,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.userFacingMessage ?? 'Download failed',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 28,
                      child: TextButton.icon(
                        onPressed: () => _manager.retryDownload(task.videoId),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(
                          'Retry',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      color: Colors.grey.withValues(alpha: 0.2),
      child: Icon(Icons.music_note, color: AppColors.textTertiary, size: 24),
    );
  }

  Widget _buildStatusIcon(DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            value: task.progress > 0 ? task.progress : null,
            color: AppColors.primary,
          ),
        );
      case DownloadStatus.pending:
        return Icon(
          Icons.hourglass_bottom,
          color: AppColors.textTertiary,
          size: 20,
        );
      case DownloadStatus.completed:
        return GestureDetector(
          onTap: () => _manager.removeTask(task.videoId),
          child: Icon(Icons.check_circle, color: AppColors.success, size: 24),
        );
      case DownloadStatus.failed:
        return GestureDetector(
          onTap: () => _manager.removeTask(task.videoId),
          child: Icon(Icons.cancel, color: AppColors.error, size: 24),
        );
    }
  }
}
