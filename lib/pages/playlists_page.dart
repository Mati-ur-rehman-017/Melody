import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../models/playlist.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/create_playlist_dialog.dart';
import 'playlist_detail_page.dart';

final Logger _log = Logger('PlaylistsPage');

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage>
    with AutomaticKeepAliveClientMixin {
  final _dbService = DatabaseService.instance;

  List<Playlist> _playlists = [];
  bool _isLoadingPlaylists = true;
  String? _playlistsErrorMessage;

  StreamSubscription<void>? _tracksChangedSubscription;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();

    _tracksChangedSubscription = _dbService.tracksChanged.listen((_) {
      _loadPlaylists();
    });
  }

  @override
  void dispose() {
    _tracksChangedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    _log.info('Loading playlists from database...');

    setState(() {
      _isLoadingPlaylists = true;
      _playlistsErrorMessage = null;
    });

    try {
      final playlists = await _dbService.getAllPlaylists();
      _log.info('Loaded ${playlists.length} playlists from database');

      final verifiedPlaylists = <Playlist>[];
      for (final playlist in playlists) {
        final tracks = await _dbService.getPlaylistTracks(playlist.id);
        verifiedPlaylists.add(playlist.copyWith(trackCount: tracks.length));
      }

      setState(() {
        _playlists = verifiedPlaylists;
        _isLoadingPlaylists = false;
      });
    } catch (e, stackTrace) {
      _log.severe('Failed to load playlists: $e');
      _log.severe('Stack trace: $stackTrace');
      setState(() {
        _playlistsErrorMessage = 'Failed to load playlists: $e';
        _isLoadingPlaylists = false;
      });
    }
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"?\n\nThis will not delete the songs from your library.',
        ),
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
      await _dbService.deletePlaylist(playlist.id);
      await _loadPlaylists();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Playlist deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting playlist: $e')));
      }
    }
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailPage(playlist: playlist),
      ),
    ).then((_) => _loadPlaylists());
  }

  Future<void> _createPlaylist() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const CreatePlaylistDialog(),
    );
    if (name != null) {
      await _dbService.createPlaylist(name);
      await _loadPlaylists();
    }
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
                        'Playlists',
                        style: AppTypography.displayMedium.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Curated collections',
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildContent() {
    final theme = Theme.of(context);

    if (_isLoadingPlaylists) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_playlistsErrorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              _playlistsErrorMessage!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPlaylists,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_playlists.isEmpty) {
      return _buildCreatePlaylistCard();
    }

    return RefreshIndicator(
      onRefresh: _loadPlaylists,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
        itemCount: _playlists.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildCreatePlaylistCard();
          }

          final playlist = _playlists[index - 1];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.large,
              boxShadow: AppShadows.bubbly,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: AppRadius.large,
              child: InkWell(
                borderRadius: AppRadius.large,
                onTap: () => _openPlaylist(playlist),
                onLongPress: () => _deletePlaylist(playlist),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.medium,
                        ),
                        child: Icon(
                          Icons.queue_music,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playlist.name,
                              style: AppTypography.labelLarge.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${playlist.trackCount ?? 0} songs',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreatePlaylistCard() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.large,
        boxShadow: AppShadows.bubbly,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.large,
        child: InkWell(
          borderRadius: AppRadius.large,
          onTap: _createPlaylist,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.medium,
                  ),
                  child: Icon(Icons.add, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Create Playlist',
                    style: AppTypography.labelLarge.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
