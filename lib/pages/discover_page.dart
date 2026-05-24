import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../models/trending_song.dart';
import '../services/trending_service.dart';
import '../theme/app_theme.dart';
import '../widgets/trending_section.dart';
import 'search_page.dart';

/// Logger instance for the discover page
final Logger _log = Logger('DiscoverPage');

/// Discover/Search page with Melody Bubbly aesthetic
///
/// Features user header, search bar, trending tracks.
/// Searching pushes [SearchPage] on top.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with AutomaticKeepAliveClientMixin {
  // Trending songs
  final TrendingService _trendingService = TrendingService();
  List<TrendingSong> _trendingSongs = [];
  List<TrendingSong> _viralSongs = [];
  bool _isLoadingTrending = true;
  bool _trendingError = false;
  bool _isOffline = false;
  DateTime? _lastTrendingUpdate;

  @override
  void initState() {
    super.initState();
    _loadTrendingSongs();
  }

  @override
  void dispose() {
    _trendingService.dispose();
    super.dispose();
  }

  /// Load trending songs from service
  Future<void> _loadTrendingSongs({bool forceRefresh = false}) async {
    setState(() {
      _isLoadingTrending = true;
      _trendingError = false;
      _isOffline = false;
    });

    try {
      final data = await _trendingService.getTrendingSongs(
        forceRefresh: forceRefresh,
      );
      final lastUpdate = await _trendingService.getLastUpdateTime();
      final isExpired = await _trendingService.isCacheExpired();

      setState(() {
        _trendingSongs = data['trending']!;
        _viralSongs = data['viral']!;
        _isLoadingTrending = false;
        _lastTrendingUpdate = lastUpdate;
        _isOffline = !isExpired && lastUpdate != null;
      });
    } catch (e) {
      _log.warning('Error loading trending songs: $e');
      setState(() {
        _isLoadingTrending = false;
        _trendingError = true;
      });
    }
  }

  /// Handle pull to refresh
  Future<void> _onRefresh() async {
    await _loadTrendingSongs(forceRefresh: true);
  }

  /// Handle trending song tap - navigate to SearchPage with query
  void _onTrendingSongTap(TrendingSong song) {
    final searchQuery = '${song.title} ${song.artist}';
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchPage(initialQuery: searchQuery)),
    );
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
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: _buildDiscoverContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build app header with name only
  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        opacity: _isLoadingTrending ? 0.82 : 1.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'melody',
              style: AppTypography.displayMedium.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build decorative search bar that navigates to SearchPage on tap
  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchPage()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.circular,
            boxShadow: AppShadows.bubbly,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Text(
                'Search for songs, artists...',
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build discover content (trending only)
  Widget _buildDiscoverContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrendingSection(
            title: 'Trending Now',
            songs: _trendingSongs,
            isLoading: _isLoadingTrending,
            isError: _trendingError,
            isOffline: _isOffline,
            onRetry: _trendingError
                ? () => _loadTrendingSongs(forceRefresh: true)
                : null,
            onSongTap: _onTrendingSongTap,
            lastUpdated: _lastTrendingUpdate,
          ),
          TrendingSection(
            title: 'Viral Hits',
            songs: _viralSongs,
            isLoading: _isLoadingTrending,
            isError: _trendingError,
            isOffline: _isOffline,
            onRetry: _trendingError
                ? () => _loadTrendingSongs(forceRefresh: true)
                : null,
            onSongTap: _onTrendingSongTap,
            lastUpdated: _lastTrendingUpdate,
          ),
        ],
      ),
    );
  }
}
