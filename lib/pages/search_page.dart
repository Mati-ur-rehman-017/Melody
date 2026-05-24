import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';

import '../services/database_service.dart';
import '../services/youtube_download_service.dart';
import '../services/audio_player_service.dart';
import '../widgets/search_result_tile.dart';

/// Logger instance for the search page
final Logger _log = Logger('SearchPage');

class SearchPage extends StatefulWidget {
  final String? initialQuery;
  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
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

  // Stream tracking
  final AudioPlayer _streamPlayer = AudioPlayer();
  String? _streamingVideoId;
  bool _isStreamLoading = false;
  StreamSubscription<PlayerState>? _streamPlayerStateSubscription;

  @override
  void initState() {
    super.initState();
    _loadDownloadedIds();
    _scrollController.addListener(_onScroll);

    // Subscribe to track changes to update download indicators
    _tracksChangedSubscription = _dbService.tracksChanged.listen((_) {
      _loadDownloadedIds();
    });

    _streamPlayerStateSubscription = _streamPlayer.playerStateStream.listen((
      state,
    ) {
      if (mounted) {
        setState(() {}); // Trigger rebuild to update play/pause icon
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performLiveSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _downloadService.dispose();
    _tracksChangedSubscription?.cancel();
    _streamPlayerStateSubscription?.cancel();
    _streamPlayer.dispose();
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Search YouTube...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
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
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
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
    );
  }

  Widget _buildContent() {
    // Initial empty state - no search yet
    if (_searchController.text.trim().isEmpty &&
        _suggestions.isEmpty &&
        _searchResults == null &&
        !_isSearching &&
        !_isLoadingSuggestions) {
      return _buildEmptyState();
    }

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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Search for music on YouTube',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Start typing to see suggestions',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSliver() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  'Suggestions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
                if (_isLoadingSuggestions) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey[500],
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
              leading: Icon(Icons.search, size: 20, color: Colors.grey[600]),
              title: Text(suggestion),
              onTap: () => _onSuggestionTap(suggestion),
            ),
          ),

          const Divider(),
        ],
      ),
    );
  }

  Widget _buildResultsSliver() {
    // Results header
    final headerWidget = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Text(
              'Results',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontSize: 12,
              ),
            ),
            if (_isSearching) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Loading state - only show spinner if no results yet
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
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red[700]),
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
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No results found for "$_lastQuery"',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
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

    // Fallback - show header only while waiting
    return headerWidget;
  }
}
