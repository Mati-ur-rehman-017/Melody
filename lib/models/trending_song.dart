/// Model for trending/viral songs from YouTube
///
/// Used for displaying trending music recommendations with caching support.
class TrendingSong {
  final String id;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final String? thumbnailPath; // Local cached path
  final Duration? duration;
  final DateTime cachedAt;

  const TrendingSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    this.thumbnailPath,
    this.duration,
    required this.cachedAt,
  });

  /// Convert to JSON for SharedPreferences caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      'thumbnailPath': thumbnailPath,
      'durationMs': duration?.inMilliseconds,
      'cachedAt': cachedAt.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON (from SharedPreferences)
  factory TrendingSong.fromJson(Map<String, dynamic> json) {
    return TrendingSong(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(json['cachedAt'] as int),
    );
  }

  /// Create a copy with updated fields
  TrendingSong copyWith({
    String? id,
    String? title,
    String? artist,
    String? thumbnailUrl,
    String? thumbnailPath,
    Duration? duration,
    DateTime? cachedAt,
  }) {
    return TrendingSong(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  String toString() {
    return 'TrendingSong(id: $id, title: $title, artist: $artist)';
  }
}
