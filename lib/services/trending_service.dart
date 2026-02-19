import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../constants.dart';
import '../models/trending_song.dart';

/// Service for fetching and caching trending/viral songs from YouTube
///
/// Features:
/// - Fetches trending and viral music from YouTube
/// - Caches metadata for 6 hours
/// - Downloads and caches thumbnails locally
/// - Provides fallback songs for offline mode
class TrendingService {
  static final Logger _log = Logger('TrendingService');

  // Cache keys
  static const String _trendingCacheKey = 'trending_songs_cache';
  static const String _viralCacheKey = 'viral_songs_cache';
  static const String _lastUpdateKey = 'trending_last_update';

  // Cache duration: 6 hours
  static const Duration _cacheDuration = Duration(hours: 6);

  final YoutubeExplode _youtube = YoutubeExplode();

  /// Get trending songs (cached or fresh)
  ///
  /// Returns a map with 'trending' and 'viral' lists
  /// If offline and no cache, returns fallback songs
  Future<Map<String, List<TrendingSong>>> getTrendingSongs({
    bool forceRefresh = false,
  }) async {
    try {
      // Check if we have valid cached data
      if (!forceRefresh) {
        final cachedData = await _getCachedSongs();
        if (cachedData != null) {
          _log.info('Using cached trending songs');
          return cachedData;
        }
      }

      // Fetch fresh data from YouTube
      _log.info('Fetching fresh trending songs from YouTube');
      final freshData = await _fetchFromYouTube();

      // Cache the fresh data
      await _cacheSongs(freshData);

      return freshData;
    } catch (e) {
      _log.warning('Failed to fetch trending songs: $e');

      // Try to return cached data even if expired
      final cachedData = await _getCachedSongs(ignoreExpiry: true);
      if (cachedData != null) {
        _log.info('Using expired cached data as fallback');
        return cachedData;
      }

      // Return fallback static songs
      _log.info('Using fallback static songs');
      return _getFallbackSongs();
    }
  }

  /// Fetch trending songs from YouTube
  Future<Map<String, List<TrendingSong>>> _fetchFromYouTube() async {
    final trendingSongs = <TrendingSong>[];
    final viralSongs = <TrendingSong>[];

    try {
      // Search for trending music
      _log.info('Searching for trending music...');
      final trendingResults = await _youtube.search.search(
        'trending music 2024 popular hits',
      );

      // Take top 5 trending songs
      var count = 0;
      for (final result in trendingResults) {
        if (count >= 5) break;

        final song = TrendingSong(
          id: result.id.value,
          title: result.title,
          artist: result.author,
          thumbnailUrl: result.thumbnails.mediumResUrl.isNotEmpty
              ? result.thumbnails.mediumResUrl
              : result.thumbnails.lowResUrl,
          duration: result.duration,
          cachedAt: DateTime.now(),
        );
        trendingSongs.add(song);
        count++;
      }

      // Search for viral songs
      _log.info('Searching for viral songs...');
      final viralResults = await _youtube.search.search(
        'viral songs 2024 tiktok trending music',
      );

      // Take top 5 viral songs
      count = 0;
      for (final result in viralResults) {
        if (count >= 5) break;

        final song = TrendingSong(
          id: result.id.value,
          title: result.title,
          artist: result.author,
          thumbnailUrl: result.thumbnails.mediumResUrl.isNotEmpty
              ? result.thumbnails.mediumResUrl
              : result.thumbnails.lowResUrl,
          duration: result.duration,
          cachedAt: DateTime.now(),
        );
        viralSongs.add(song);
        count++;
      }

      // Download thumbnails
      await _downloadThumbnails([...trendingSongs, ...viralSongs]);
    } catch (e) {
      _log.severe('Error fetching from YouTube: $e');
      rethrow;
    }

    return {'trending': trendingSongs, 'viral': viralSongs};
  }

  /// Get cached songs if available and not expired
  Future<Map<String, List<TrendingSong>>?> _getCachedSongs({
    bool ignoreExpiry = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check last update time
      final lastUpdate = prefs.getInt(_lastUpdateKey);
      if (lastUpdate == null) return null;

      final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      final age = DateTime.now().difference(lastUpdateTime);

      if (!ignoreExpiry && age > _cacheDuration) {
        _log.info('Cache expired (age: ${age.inHours} hours)');
        return null;
      }

      // Load cached data
      final trendingJson = prefs.getString(_trendingCacheKey);
      final viralJson = prefs.getString(_viralCacheKey);

      if (trendingJson == null || viralJson == null) return null;

      final trendingList = (jsonDecode(trendingJson) as List)
          .map((e) => TrendingSong.fromJson(e as Map<String, dynamic>))
          .toList();

      final viralList = (jsonDecode(viralJson) as List)
          .map((e) => TrendingSong.fromJson(e as Map<String, dynamic>))
          .toList();

      return {'trending': trendingList, 'viral': viralList};
    } catch (e) {
      _log.warning('Error reading cache: $e');
      return null;
    }
  }

  /// Cache songs to SharedPreferences
  Future<void> _cacheSongs(Map<String, List<TrendingSong>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final trendingJson = jsonEncode(
        data['trending']!.map((s) => s.toJson()).toList(),
      );
      final viralJson = jsonEncode(
        data['viral']!.map((s) => s.toJson()).toList(),
      );

      await prefs.setString(_trendingCacheKey, trendingJson);
      await prefs.setString(_viralCacheKey, viralJson);
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);

      _log.info(
        'Cached ${data['trending']!.length} trending and ${data['viral']!.length} viral songs',
      );
    } catch (e) {
      _log.warning('Error caching songs: $e');
    }
  }

  /// Download thumbnails to local storage
  Future<void> _downloadThumbnails(List<TrendingSong> songs) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbDir = Directory('${appDir.path}/trending_thumbnails');

      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }

      for (final song in songs) {
        if (song.thumbnailUrl.isEmpty) continue;

        final fileName = 'trending_${song.id}.jpg';
        final filePath = '${thumbDir.path}/$fileName';
        final file = File(filePath);

        // Skip if already cached
        if (await file.exists()) continue;

        try {
          // Download thumbnail
          final client = HttpClient();
          final request = await client.getUrl(Uri.parse(song.thumbnailUrl));
          final response = await request.close();

          if (response.statusCode == 200) {
            final bytes = await response.fold<List<int>>(
              [],
              (prev, element) => prev..addAll(element),
            );
            await file.writeAsBytes(bytes);
            _log.fine('Downloaded thumbnail for ${song.title}');
          }
          client.close();
        } catch (e) {
          _log.warning('Failed to download thumbnail for ${song.title}: $e');
        }
      }
    } catch (e) {
      _log.warning('Error downloading thumbnails: $e');
    }
  }

  /// Get fallback static songs for offline mode
  Map<String, List<TrendingSong>> _getFallbackSongs() {
    final now = DateTime.now();

    final trendingSongs = AppConstants.fallbackTrendingSongs
        .map(
          (song) => TrendingSong(
            id: 'fallback_${song['title']}',
            title: song['title']!,
            artist: song['artist']!,
            thumbnailUrl: '',
            duration: null,
            cachedAt: now,
          ),
        )
        .toList();

    final viralSongs = AppConstants.fallbackViralSongs
        .map(
          (song) => TrendingSong(
            id: 'fallback_${song['title']}',
            title: song['title']!,
            artist: song['artist']!,
            thumbnailUrl: '',
            duration: null,
            cachedAt: now,
          ),
        )
        .toList();

    return {'trending': trendingSongs, 'viral': viralSongs};
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_trendingCacheKey);
      await prefs.remove(_viralCacheKey);
      await prefs.remove(_lastUpdateKey);

      // Clear thumbnails
      final appDir = await getApplicationDocumentsDirectory();
      final thumbDir = Directory('${appDir.path}/trending_thumbnails');
      if (await thumbDir.exists()) {
        await thumbDir.delete(recursive: true);
      }

      _log.info('Cache cleared');
    } catch (e) {
      _log.warning('Error clearing cache: $e');
    }
  }

  /// Get last update time
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey);
      if (lastUpdate == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(lastUpdate);
    } catch (e) {
      return null;
    }
  }

  /// Check if cache is expired
  Future<bool> isCacheExpired() async {
    final lastUpdate = await getLastUpdateTime();
    if (lastUpdate == null) return true;
    return DateTime.now().difference(lastUpdate) > _cacheDuration;
  }

  void dispose() {
    _youtube.close();
  }
}
