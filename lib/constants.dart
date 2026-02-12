/// Categories for the Discover screen
class Category {
  final String id;
  final String name;
  final String icon;
  final int colorValue;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
  });
}

/// Recommended track for the Discover screen
class RecommendedTrack {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String category;
  final String imageAsset;
  final int backgroundColor;
  final int accentColor;

  const RecommendedTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.category,
    required this.imageAsset,
    required this.backgroundColor,
    required this.accentColor,
  });
}

/// Library track for the Library screen
class LibraryTrack {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String category;
  final String imageAsset;
  final int backgroundColor;
  final int accentColor;
  final bool isFavorite;

  const LibraryTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.category,
    required this.imageAsset,
    required this.backgroundColor,
    required this.accentColor,
    this.isFavorite = false,
  });
}

/// Playlist for the Library screen
class PlaylistPreview {
  final String id;
  final String name;
  final String imageAsset;
  final int backgroundColor;

  const PlaylistPreview({
    required this.id,
    required this.name,
    required this.imageAsset,
    required this.backgroundColor,
  });
}

/// App constants matching the React reference
class AppConstants {
  // Category data - Music genres
  static const List<Category> categories = [
    Category(
      id: '1',
      name: 'Pop',
      icon: 'music_note',
      colorValue: 0xFFE67E5F, // Primary - Terracotta
    ),
    Category(
      id: '2',
      name: 'Rock',
      icon: 'electric_bolt',
      colorValue: 0xFFF4C430, // Accent - Mustard
    ),
    Category(
      id: '3',
      name: 'Jazz',
      icon: 'piano',
      colorValue: 0xFF60A5FA, // Blue
    ),
    Category(
      id: '4',
      name: 'Electronic',
      icon: 'graphic_eq',
      colorValue: 0xFF22C55E, // Green
    ),
    Category(
      id: '5',
      name: 'Classical',
      icon: 'piano',
      colorValue: 0xFFA855F7, // Purple
    ),
  ];

  // Recommended tracks data
  static const List<RecommendedTrack> recommendedTracks = [
    RecommendedTrack(
      id: 'r1',
      title: 'Connecting Beyond Words',
      artist: '30 min • English',
      duration: '30:00',
      category: 'TOUCHING',
      imageAsset: 'assets/images/track_1.png',
      backgroundColor: 0xFFF2E8D5,
      accentColor: 0xFF1A2E35, // Secondary
    ),
    RecommendedTrack(
      id: 'r2',
      title: 'Unlocking Empathy',
      artist: '25 min • English',
      duration: '25:00',
      category: 'LISTENING',
      imageAsset: 'assets/images/track_2.png',
      backgroundColor: 0xFFE5EDF0,
      accentColor: 0xFFE67E5F, // Primary
    ),
    RecommendedTrack(
      id: 'r3',
      title: 'Vocal Mastery',
      artist: '45 min • English',
      duration: '45:00',
      category: 'SPEAKING',
      imageAsset: 'assets/images/track_3.png',
      backgroundColor: 0xFFFDE4E4,
      accentColor: 0xFFF4C430, // Accent
    ),
    RecommendedTrack(
      id: 'r4',
      title: 'Morning Rituals',
      artist: '12 min • English',
      duration: '12:00',
      category: 'MINDSET',
      imageAsset: 'assets/images/track_4.png',
      backgroundColor: 0xFFE9F4F0,
      accentColor: 0xFF1A2E35, // Secondary
    ),
  ];

  // Library tracks data
  static const List<LibraryTrack> libraryTracks = [
    LibraryTrack(
      id: 'l1',
      title: 'Beyond the Horizon',
      artist: 'Lofi Dreaming',
      duration: '3:45',
      category: 'Lofi',
      imageAsset: 'assets/images/album_1.png',
      backgroundColor: 0xFFFFFFFF,
      accentColor: 0xFFE67E5F,
      isFavorite: false,
    ),
    LibraryTrack(
      id: 'l2',
      title: 'Neon Soul',
      artist: 'The Electric Funk',
      duration: '4:12',
      category: 'Funk',
      imageAsset: 'assets/images/album_2.png',
      backgroundColor: 0xFFFFFFFF,
      accentColor: 0xFFE67E5F,
      isFavorite: true,
    ),
    LibraryTrack(
      id: 'l3',
      title: 'Forest Rain',
      artist: 'Ambient Nature',
      duration: '10:00',
      category: 'Ambient',
      imageAsset: 'assets/images/album_3.png',
      backgroundColor: 0xFFFFFFFF,
      accentColor: 0xFFE67E5F,
      isFavorite: false,
    ),
    LibraryTrack(
      id: 'l4',
      title: 'Midnight Pulse',
      artist: 'Synthwave Collective',
      duration: '5:24',
      category: 'Synthwave',
      imageAsset: 'assets/images/album_4.png',
      backgroundColor: 0xFFFFFFFF,
      accentColor: 0xFFE67E5F,
      isFavorite: false,
    ),
  ];

  // Jump back in playlists
  static const List<PlaylistPreview> jumpBackIn = [
    PlaylistPreview(
      id: 'jb1',
      name: 'Morning Brew',
      imageAsset: 'assets/images/playlist_1.png',
      backgroundColor: 0xFFFDE4E4, // Primary light
    ),
    PlaylistPreview(
      id: 'jb2',
      name: 'Deep Work',
      imageAsset: 'assets/images/playlist_2.png',
      backgroundColor: 0xFFE5EDF0, // Blue tint
    ),
  ];
}
