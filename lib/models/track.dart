/// Represents a downloaded audio track with its metadata.
class Track {
  /// YouTube video ID (unique identifier)
  final String id;

  /// Video/track title
  final String title;

  /// Channel/artist name
  final String author;

  /// Duration in milliseconds (null if unknown)
  final int? durationMs;

  /// Relative file path from app documents directory (e.g., "audio/dQw4w9WgXcQ.webm")
  final String filePath;

  /// File size in bytes
  final int? fileSize;

  /// Audio bitrate in kbps
  final int? bitrateKbps;

  /// Audio container format (e.g., "webm", "mp4")
  final String? container;

  /// When the track was downloaded
  final DateTime downloadedAt;

  /// YouTube thumbnail URL (original source)
  final String? thumbnailUrl;

  /// Relative path to locally saved thumbnail (e.g., "thumbnails/dQw4w9WgXcQ.jpg")
  final String? thumbnailPath;

  const Track({
    required this.id,
    required this.title,
    required this.author,
    this.durationMs,
    required this.filePath,
    this.fileSize,
    this.bitrateKbps,
    this.container,
    required this.downloadedAt,
    this.thumbnailUrl,
    this.thumbnailPath,
  });

  /// Get duration as Duration object
  Duration? get duration =>
      durationMs != null ? Duration(milliseconds: durationMs!) : null;

  /// Get formatted duration string (mm:ss or hh:mm:ss)
  String get formattedDuration {
    final d = duration;
    if (d == null) return '--:--';

    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted file size string
  String get formattedFileSize {
    if (fileSize == null) return 'Unknown';
    final bytes = fileSize!;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'duration_ms': durationMs,
      'file_path': filePath,
      'file_size': fileSize,
      'bitrate_kbps': bitrateKbps,
      'container': container,
      'downloaded_at': downloadedAt.millisecondsSinceEpoch,
      'thumbnail_url': thumbnailUrl,
      'thumbnail_path': thumbnailPath,
    };
  }

  /// Create Track from database Map
  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      durationMs: map['duration_ms'] as int?,
      filePath: map['file_path'] as String,
      fileSize: map['file_size'] as int?,
      bitrateKbps: map['bitrate_kbps'] as int?,
      container: map['container'] as String?,
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(
        map['downloaded_at'] as int,
      ),
      thumbnailUrl: map['thumbnail_url'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
    );
  }

  /// Create a copy with optional field overrides
  Track copyWith({
    String? id,
    String? title,
    String? author,
    int? durationMs,
    String? filePath,
    int? fileSize,
    int? bitrateKbps,
    String? container,
    DateTime? downloadedAt,
    String? thumbnailUrl,
    String? thumbnailPath,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      durationMs: durationMs ?? this.durationMs,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      container: container ?? this.container,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  @override
  String toString() {
    return 'Track(id: $id, title: $title, author: $author)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Track && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
