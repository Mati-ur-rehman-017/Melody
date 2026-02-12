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
  final String subtitle;
  final String duration;
  final String category;
  final String imageAsset;
  final int backgroundColor;

  const RecommendedTrack({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.category,
    required this.imageAsset,
    required this.backgroundColor,
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

  // Recommended tracks data - Modern music playlists
  static const List<RecommendedTrack> recommendedTracks = [
    RecommendedTrack(
      id: 'r1',
      title: 'Liked Songs',
      subtitle: '248 tracks',
      duration: '12:45',
      category: 'Pop',
      imageAsset: 'assets/images/album_1.png',
      backgroundColor: 0xFF2C1810, // Dark brown
    ),
    RecommendedTrack(
      id: 'r2',
      title: 'Gym & High Energy',
      subtitle: '42 tracks',
      duration: '2:30',
      category: 'Rock',
      imageAsset: 'assets/images/album_2.png',
      backgroundColor: 0xFF1A1A1A, // Dark gray
    ),
    RecommendedTrack(
      id: 'r3',
      title: 'Midnight Jazz',
      subtitle: '86 tracks',
      duration: '5:20',
      category: 'Jazz',
      imageAsset: 'assets/images/album_3.png',
      backgroundColor: 0xFF0F1419, // Dark blue-black
    ),
    RecommendedTrack(
      id: 'r4',
      title: 'Deep Focus',
      subtitle: '120 tracks',
      duration: '8:15',
      category: 'Electronic',
      imageAsset: 'assets/images/album_4.png',
      backgroundColor: 0xFF151515, // Almost black
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

  // Fallback trending songs for offline mode
  static const List<Map<String, String>> fallbackTrendingSongs = [
    {
      'title': 'Cruel Summer',
      'artist': 'Taylor Swift',
      'searchQuery': 'Cruel Summer Taylor Swift',
    },
    {'title': 'Seven', 'artist': 'Jung Kook', 'searchQuery': 'Seven Jung Kook'},
    {
      'title': 'Vampire',
      'artist': 'Olivia Rodrigo',
      'searchQuery': 'Vampire Olivia Rodrigo',
    },
    {
      'title': 'Paint The Town Red',
      'artist': 'Doja Cat',
      'searchQuery': 'Paint The Town Red Doja Cat',
    },
    {
      'title': 'What Was I Made For',
      'artist': 'Billie Eilish',
      'searchQuery': 'What Was I Made For Billie Eilish',
    },
  ];

  // Fallback viral songs for offline mode
  static const List<Map<String, String>> fallbackViralSongs = [
    {
      'title': 'Last Night',
      'artist': 'Morgan Wallen',
      'searchQuery': 'Last Night Morgan Wallen',
    },
    {'title': 'Snooze', 'artist': 'SZA', 'searchQuery': 'Snooze SZA'},
    {'title': 'Kill Bill', 'artist': 'SZA', 'searchQuery': 'Kill Bill SZA'},
    {
      'title': 'Anti-Hero',
      'artist': 'Taylor Swift',
      'searchQuery': 'Anti-Hero Taylor Swift',
    },
    {
      'title': 'Flowers',
      'artist': 'Miley Cyrus',
      'searchQuery': 'Flowers Miley Cyrus',
    },
  ];
}
