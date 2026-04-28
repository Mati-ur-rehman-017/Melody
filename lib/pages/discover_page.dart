import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';

import '../models/trending_song.dart';
import '../services/database_service.dart';
import '../services/trending_service.dart';
import '../services/youtube_download_service.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/search_result_tile.dart';
import '../widgets/trending_section.dart';

/// Logger instance for the search page
final Logger _log = Logger('DiscoverPage');

/// Discover/Search page with Melody Bubbly aesthetic
///
/// Features user header, search bar, categories, and recommended tracks
/// while maintaining full YouTube search and download functionality.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _downloadService = YouTubeDownloadService();
  final _dbService = DatabaseService.instance;

  // Search results state
  VideoSearchList? _searchResults;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasMoreResults = true;
  String? _errorMessage;
  String _lastQuery = '';

  // Suggestions state
  List<String> _suggestions = [];
  bool _isLoadingSuggestions = false;

  // Debounce timer for live search
  Timer? _debounceTimer;
  late final AnimationController _suggestionsRotationController;
  late final Animation<double> _suggestionsTurns;

  // Download tracking
  Set<String> _downloadedIds = {};
  final Map<String, double> _activeDownloads = {};

  StreamSubscription<void>? _tracksChangedSubscription;

  // Stream tracking
  final AudioPlayer _streamPlayer = AudioPlayer();
  String? _streamingVideoId;
  bool _isStreamLoading = false;
  StreamSubscription<PlayerState>? _streamPlayerStateSubscription;

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
    _suggestionsRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _suggestionsTurns = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _suggestionsRotationController,
        curve: Curves.linear,
      ),
    );
    _loadDownloadedIds();
    _scrollController.addListener(_onScroll);
    _loadTrendingSongs();

    // Subscribe to track changes to update download indicators
    _tracksChangedSubscription = _dbService.tracksChanged.listen((_) {
      _loadDownloadedIds();
    });

    _streamPlayerStateSubscription = _streamPlayer.playerStateStream.listen((
      state,
    ) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _suggestionsRotationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _downloadService.dispose();
    _trendingService.dispose();
    _tracksChangedSubscription?.cancel();
    _streamPlayerStateSubscription?.cancel();
    _streamPlayer.dispose();
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

  /// Handle trending song tap
  void _onTrendingSongTap(TrendingSong song) {
    final searchQuery = '${song.title} ${song.artist}';
    _searchController.text = searchQuery;
    _performLiveSearch(searchQuery);
  }

  /// Load all downloaded track IDs from the database
  Future<void> _loadDownloadedIds() async {
    try {
      final tracks = await _dbService.getAllTracks();
      setState(() {
        _downloadedIds = tracks.map((t) => t.id).toSet();
      });
    } catch (e) {
      _log.warning('Failed to load downloaded IDs: $e');
    }
  }

  /// Handle scroll events for pagination
  void _onScroll() {
    if (_isLoadingMore || !_hasMoreResults || _searchResults == null) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const threshold = 200.0;

    if (maxScroll - currentScroll <= threshold) {
      _loadMoreResults();
    }
  }

  /// Handle search text changes with debounce
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _suggestions = [];
        _searchResults = null;
        _errorMessage = null;
        _isSearching = false;
        _isLoadingSuggestions = false;
      });
      return;
    }

    // Start debounce timer
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performLiveSearch(trimmed);
    });
  }

  /// Perform live search - loads suggestions and results in parallel
  Future<void> _performLiveSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoadingSuggestions = true;
      _isSearching = true;
      _errorMessage = null;
      _lastQuery = query;
      _hasMoreResults = true;
    });

    // Run suggestions and search in parallel
    try {
      // Start both requests
      final suggestionsFuture = _downloadService.getSearchSuggestions(query);
      final searchFuture = _downloadService.searchVideos(query);

      // Handle suggestions result
      suggestionsFuture
          .then((suggestions) {
            if (mounted && _lastQuery == query) {
              setState(() {
                _suggestions = suggestions.take(4).toList();
                _isLoadingSuggestions = false;
              });
            }
          })
          .catchError((e) {
            _log.warning('Suggestions failed: $e');
            if (mounted) {
              setState(() {
                _suggestions = [];
                _isLoadingSuggestions = false;
              });
            }
          });

      // Handle search result
      final searchResult = await searchFuture;
      if (mounted && _lastQuery == query) {
        setState(() {
          _searchResults = searchResult;
          _isSearching = false;
          _hasMoreResults = searchResult.isNotEmpty;
        });
      }
    } catch (e) {
      _log.severe('Search failed: $e');
      if (mounted && _lastQuery == query) {
        setState(() {
          _isSearching = false;
          _isLoadingSuggestions = false;
          _errorMessage = 'Search failed: ${e.toString()}';
        });
      }
    }
  }

  /// Handle suggestion tap - search with that term directly
  void _onSuggestionTap(String suggestion) {
    _debounceTimer?.cancel();

    // Clear suggestions and search with this term
    setState(() {
      _suggestions = [];
      _lastQuery = suggestion;
    });

    _performLiveSearch(suggestion);
  }

  /// Load more results (pagination)
  Future<void> _loadMoreResults() async {
    if (_searchResults == null || _isLoadingMore || !_hasMoreResults) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = await _searchResults!.nextPage();
      setState(() {
        if (nextPage == null || nextPage.isEmpty) {
          _hasMoreResults = false;
        } else {
          _searchResults = nextPage;
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      _log.warning('Failed to load more results: $e');
      setState(() {
        _isLoadingMore = false;
        _hasMoreResults = false;
      });
    }
  }

  Future<void> _toggleStream(Video video) async {
    final videoId = video.id.value;

    // If tapping the currently streaming video, toggle play/pause
    if (_streamingVideoId == videoId) {
      if (_streamPlayer.playing) {
        await _streamPlayer.pause();
      } else {
        // Pause main app player if it's playing before we resume
        if (AudioPlayerService.instance.isPlaying) {
          await AudioPlayerService.instance.pause();
        }
        await _streamPlayer.play();
      }
      return;
    }

    // Otherwise, start a new stream
    setState(() {
      _streamingVideoId = videoId;
      _isStreamLoading = true;
    });

    try {
      // Pause main app player if it's playing
      if (AudioPlayerService.instance.isPlaying) {
        await AudioPlayerService.instance.pause();
      }

      final url = await _downloadService.getAudioStreamUrl(videoId);

      if (url != null && mounted) {
        await _streamPlayer.setUrl(url);
        if (_streamingVideoId == videoId) {
          // Check if user hasn't switched again
          await _streamPlayer.play();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load audio stream')),
        );
        setState(() {
          _streamingVideoId = null;
        });
      }
    } catch (e) {
      _log.severe('Error starting stream: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error playing stream')));
        setState(() {
          _streamingVideoId = null;
        });
      }
    } finally {
      if (mounted && _streamingVideoId == videoId) {
        setState(() {
          _isStreamLoading = false;
        });
      }
    }
  }

  /// Download a video
  Future<void> _downloadVideo(Video video) async {
    final videoId = video.id.value;

    // Already downloading or downloaded
    if (_activeDownloads.containsKey(videoId) ||
        _downloadedIds.contains(videoId)) {
      return;
    }

    setState(() {
      _activeDownloads[videoId] = 0.0;
    });

    try {
      final result = await _downloadService.downloadAudio(
        videoId,
        onProgress: (progress) {
          setState(() {
            _activeDownloads[videoId] = progress.percentage / 100;
          });
        },
      );

      setState(() {
        _activeDownloads.remove(videoId);
      });

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded: ${video.title}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Download failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      _log.severe('Download error: $e');
      setState(() {
        _activeDownloads.remove(videoId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          children: [
            // Header
            _buildHeader(),

            // Search Bar
            _buildSearchBar(),

            // Main content
            Expanded(
              child: _searchResults != null || _isSearching
                  ? _buildSearchResults()
                  : RefreshIndicator(
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
            // App name
            Text(
              'Melody',
              style: AppTypography.displayMedium.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build rounded search bar
  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.circular,
          boxShadow: AppShadows.bubbly,
        ),
        child: TextField(
          controller: _searchController,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search for songs, artists...',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            prefixIcon: Icon(
              Icons.search,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _debounceTimer?.cancel();
                      setState(() {
                        _suggestions = [];
                        _searchResults = null;
                        _errorMessage = null;
                        _isSearching = false;
                        _isLoadingSuggestions = false;
                      });
                    },
                  )
                : Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: RotationTransition(
                      turns: _isLoadingSuggestions
                          ? _suggestionsTurns
                          : const AlwaysStoppedAnimation<double>(0),
                      child: Icon(
                        Icons.tune,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
          onSubmitted: (query) {
            _debounceTimer?.cancel();
            final trimmed = query.trim();
            if (trimmed.isNotEmpty) {
              _performLiveSearch(trimmed);
            }
          },
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
          // Trending Now section
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

          // Viral Hits section
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

  /// Build search results view
  Widget _buildSearchResults() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Suggestions section
        if (_suggestions.isNotEmpty || _isLoadingSuggestions)
          _buildSuggestionsSliver(),

        // Results section
        _buildResultsSliver(),
      ],
    );
  }

  /// Build suggestions sliver
  Widget _buildSuggestionsSliver() {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        opacity: _suggestions.isNotEmpty ? 1.0 : 0.45,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Text(
                    'Suggestions',
                    style: AppTypography.labelLarge.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  if (_isLoadingSuggestions) ...[
                    const SizedBox(width: 8),
                    RotationTransition(
                      turns: _suggestionsTurns,
                      child: Icon(
                        Icons.autorenew,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Suggestion items
            ..._suggestions.map(
              (suggestion) => ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(
                  Icons.search,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                title: Text(suggestion, style: AppTypography.bodyMedium),
                onTap: () => _onSuggestionTap(suggestion),
              ),
            ),

            const Divider(indent: 24, endIndent: 24),
          ],
        ),
      ),
    );
  }

  /// Build results sliver
  Widget _buildResultsSliver() {
    final theme = Theme.of(context);
    // Results header
    final headerWidget = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: Row(
          children: [
            Text(
              'Results',
              style: AppTypography.labelLarge.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (_isSearching) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Loading state
    if (_isSearching && _searchResults == null) {
      return SliverMainAxisGroup(
        slivers: [
          headerWidget,
          const SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      );
    }

    // Error state
    if (_errorMessage != null) {
      return SliverMainAxisGroup(
        slivers: [
          headerWidget,
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _performLiveSearch(_lastQuery),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // No results
    if (_searchResults != null && _searchResults!.isEmpty) {
      return SliverMainAxisGroup(
        slivers: [
          headerWidget,
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results found for "$_lastQuery"',
                    style: AppTypography.bodyLarge.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Results list
    if (_searchResults != null) {
      return SliverMainAxisGroup(
        slivers: [
          headerWidget,
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              // Loading more indicator
              if (index >= _searchResults!.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final video = _searchResults![index];
              final videoId = video.id.value;
              final isDownloaded = _downloadedIds.contains(videoId);
              final isDownloading = _activeDownloads.containsKey(videoId);
              final progress = _activeDownloads[videoId];

              return SearchResultTile(
                video: video,
                isDownloaded: isDownloaded,
                isDownloading: isDownloading,
                downloadProgress: progress,
                onDownload: () => _downloadVideo(video),
                isStreaming:
                    _streamingVideoId == videoId && _streamPlayer.playing,
                isStreamLoading:
                    _streamingVideoId == videoId && _isStreamLoading,
                onStreamToggle: () => _toggleStream(video),
              );
            }, childCount: _searchResults!.length + (_isLoadingMore ? 1 : 0)),
          ),
        ],
      );
    }

    // Fallback
    return headerWidget;
  }
}
