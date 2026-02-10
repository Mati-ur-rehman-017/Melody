/// Represents a playlist containing audio tracks.
class Playlist {
  /// Unique identifier for the playlist
  final String id;

  /// Name of the playlist
  final String name;

  /// When the playlist was created
  final DateTime createdAt;

  /// Number of tracks in the playlist (optional, for display purposes)
  final int? trackCount;

  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    this.trackCount,
  });

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create Playlist from database Map
  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      trackCount: map['track_count'] as int?,
    );
  }

  /// Create a copy with optional field overrides
  Playlist copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    int? trackCount,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      trackCount: trackCount ?? this.trackCount,
    );
  }

  @override
  String toString() {
    return 'Playlist(id: $id, name: $name, trackCount: $trackCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Playlist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
