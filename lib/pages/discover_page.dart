import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../constants.dart';
import '../services/database_service.dart';
import '../services/youtube_download_service.dart';
import '../theme/app_theme.dart';
import '../widgets/search_result_tile.dart';

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

class _DiscoverPageState extends State<DiscoverPage> {
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

  // Download tracking
  Set<String> _downloadedIds = {};
  final Map<String, double> _activeDownloads = {};

  StreamSubscription<void>? _tracksChangedSubscription;

  @override
  void initState() {
    super.initState();
    _loadDownloadedIds();
    _scrollController.addListener(_onScroll);

    // Subscribe to track changes to update download indicators
    _tracksChangedSubscription = _dbService.tracksChanged.listen((_) {
      _loadDownloadedIds();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _downloadService.dispose();
    _tracksChangedSubscription?.cancel();
    super.dispose();
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
  Widget build(BuildContext context) {
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
                  : _buildDiscoverContent(),
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
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            prefixIcon: Icon(
              Icons.search,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tune,
                      size: 16,
                      color: AppColors.primary,
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

  /// Build discover content (categories + recommended)
  Widget _buildDiscoverContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categories section
          _buildCategoriesSection(),

          // Recommended section
          _buildRecommendedSection(),
        ],
      ),
    );
  }

  /// Build categories horizontal scroll
  Widget _buildCategoriesSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categories',
                style: AppTypography.heading2.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'See all',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Categories row - equally spaced
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: AppConstants.categories.map((category) {
              return Expanded(child: _buildCategoryItem(category));
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Build individual category item
  Widget _buildCategoryItem(Category category) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _onCategoryTap(category.name),
      child: Column(
        children: [
          // Category icon bubble
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              boxShadow: AppShadows.bubbly,
            ),
            child: Icon(
              _getCategoryIcon(category.icon),
              color: Color(category.colorValue),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          // Category name
          Text(
            category.name,
            style: AppTypography.labelMedium.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Get Flutter icon from string name
  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'music_note':
        return Icons.music_note;
      case 'electric_bolt':
        return Icons.electric_bolt;
      case 'piano':
        return Icons.music_note;
      case 'graphic_eq':
        return Icons.graphic_eq;
      case 'touch_app':
        return Icons.touch_app;
      case 'hearing':
        return Icons.hearing;
      case 'campaign':
        return Icons.campaign;
      case 'visibility':
        return Icons.visibility;
      case 'psychology':
        return Icons.psychology;
      default:
        return Icons.category;
    }
  }

  /// Handle category tap - search for the category
  void _onCategoryTap(String categoryName) {
    final searchQuery = '$categoryName music';
    _searchController.text = searchQuery;
    _performLiveSearch(searchQuery);
  }

  /// Build recommended section
  Widget _buildRecommendedSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recommended',
                style: AppTypography.heading2.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                Icons.more_horiz,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                size: 24,
              ),
            ],
          ),
        ),

        // 2-column grid with modern cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: AppConstants.recommendedTracks.length,
            itemBuilder: (context, index) {
              final track = AppConstants.recommendedTracks[index];
              return _buildModernTrackCard(track);
            },
          ),
        ),
      ],
    );
  }

  /// Build modern track card with Image 2 style
  Widget _buildModernTrackCard(RecommendedTrack track) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        // Search for this playlist
        _searchController.text = track.title;
        _performLiveSearch(track.title);
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.large,
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album art with play button overlay
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // Album art background
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Color(track.backgroundColor),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      child: Container(
                        color: Color(track.backgroundColor),
                        child: Center(
                          child: Icon(
                            Icons.music_note,
                            color: Colors.white.withOpacity(0.3),
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Play button
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Track info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title
                    Text(
                      track.title,
                      style: AppTypography.labelLarge.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Subtitle (track count)
                    Row(
                      children: [
                        Icon(
                          Icons.music_note,
                          size: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          track.subtitle,
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                if (_isLoadingSuggestions) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              title: Text(suggestion, style: AppTypography.bodyMedium),
              onTap: () => _onSuggestionTap(suggestion),
            ),
          ),

          const Divider(indent: 24, endIndent: 24),
        ],
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
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            if (_isSearching) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                    const Icon(
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
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results found for "$_lastQuery"',
                    style: AppTypography.bodyLarge.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
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
