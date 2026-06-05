import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/download_task.dart';
import '../models/playlist.dart';
import '../models/track.dart';

/// Logger instance for the database service
final Logger _log = Logger('DatabaseService');

/// Database version for migrations
const int _databaseVersion = 5;

/// Database filename
const String _databaseName = 'melody.db';

/// Singleton service for SQLite database operations
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  /// Stream controller for notifying listeners when tracks change
  final StreamController<void> _tracksChangedController =
      StreamController<void>.broadcast();

  /// Stream that emits when tracks are added or deleted
  Stream<void> get tracksChanged => _tracksChangedController.stream;

  /// Whether the service has been initialized
  bool get isInitialized => _database != null;

  /// Initialize the database service
  ///
  /// Must be called before any database operations.
  /// Automatically configures FFI for desktop platforms.
  Future<void> initialize() async {
    if (_database != null) {
      _log.fine('Database already initialized');
      return;
    }

    _log.info('Initializing database service...');

    // Initialize FFI for desktop platforms
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      _log.fine('Configuring SQLite FFI for desktop platform');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Get database path
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(appDir.path, _databaseName);
    _log.fine('Database path: $dbPath');

    // Open database
    _database = await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Ensure schema is up to date (handles edge cases where migration didn't run)
    await _ensureSchemaUpToDate();

    _log.info('Database initialized successfully');
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    _log.info('Creating database tables (version $version)');

    await db.execute('''
      CREATE TABLE tracks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        duration_ms INTEGER,
        file_path TEXT NOT NULL,
        file_size INTEGER,
        bitrate_kbps INTEGER,
        container TEXT,
        downloaded_at INTEGER NOT NULL,
        thumbnail_url TEXT,
        thumbnail_path TEXT
      )
    ''');

    // Index for sorting by download date
    await db.execute('''
      CREATE INDEX idx_tracks_downloaded_at ON tracks(downloaded_at)
    ''');

    // Download tasks table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS download_tasks (
        video_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        thumbnail_url TEXT,
        status INTEGER NOT NULL,
        progress REAL NOT NULL DEFAULT 0.0,
        error_message TEXT,
        user_facing_message TEXT,
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    _log.info('Database tables created');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _log.info('Upgrading database from v$oldVersion to v$newVersion');

    // Migration from v1 to v2: add thumbnail_path column
    if (oldVersion < 2) {
      _log.info('Adding thumbnail_path column...');
      await db.execute('ALTER TABLE tracks ADD COLUMN thumbnail_path TEXT');
      _log.info('Migration to v2 complete');
    }

    // Migration from v2 to v3: add playlists and playlist_tracks tables
    if (oldVersion < 3) {
      _log.info('Creating playlist tables...');
      await _createPlaylistTables(db);
      _log.info('Migration to v3 complete');
    }

    // Migration from v3 to v4: add waveforms table
    if (oldVersion < 4) {
      _log.info('Creating waveforms table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS waveforms (
          track_id TEXT PRIMARY KEY,
          amplitudes TEXT NOT NULL,
          samples_per_second INTEGER NOT NULL,
          duration_ms INTEGER NOT NULL,
          extracted_at TEXT NOT NULL
        )
      ''');
      _log.info('Migration to v4 complete');
    }

    // Migration from v4 to v5: add download_tasks table
    if (oldVersion < 5) {
      _log.info('Creating download_tasks table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS download_tasks (
          video_id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          author TEXT NOT NULL,
          thumbnail_url TEXT,
          status INTEGER NOT NULL,
          progress REAL NOT NULL DEFAULT 0.0,
          error_message TEXT,
          user_facing_message TEXT,
          started_at INTEGER NOT NULL,
          completed_at INTEGER,
          retry_count INTEGER NOT NULL DEFAULT 0
        )
      ''');
      _log.info('Migration to v5 complete');
    }
  }

  /// Create playlist tables
  Future<void> _createPlaylistTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlist_tracks (
        playlist_id TEXT NOT NULL,
        track_id TEXT NOT NULL,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, track_id),
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
        FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist_id ON playlist_tracks(playlist_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_playlist_tracks_track_id ON playlist_tracks(track_id)
    ''');
  }

  /// Ensure the database schema is up to date
  ///
  /// This handles cases where the migration didn't run properly.
  Future<void> _ensureSchemaUpToDate() async {
    // Check if thumbnail_path column exists
    final tableInfo = await _database!.rawQuery('PRAGMA table_info(tracks)');
    final columns = tableInfo.map((row) => row['name'] as String).toSet();

    if (!columns.contains('thumbnail_path')) {
      _log.warning('thumbnail_path column missing, adding it now...');
      await _database!.execute(
        'ALTER TABLE tracks ADD COLUMN thumbnail_path TEXT',
      );
      _log.info('Added missing thumbnail_path column');
    }

    // Check if playlists table exists
    final tables = await _database!.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='playlists'",
    );
    if (tables.isEmpty) {
      _log.warning('Playlist tables missing, creating them now...');
      await _createPlaylistTables(_database!);
      _log.info('Created missing playlist tables');
    }
  }

  /// Ensure database is initialized
  void _ensureInitialized() {
    if (_database == null) {
      throw StateError(
        'DatabaseService not initialized. Call initialize() first.',
      );
    }
  }

  /// Insert a new track into the database
  Future<void> insertTrack(Track track) async {
    _ensureInitialized();
    _log.fine('Inserting track: ${track.id}');

    await _database!.insert(
      'tracks',
      track.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _log.info('Track inserted: ${track.title}');

    // Notify listeners that tracks have changed
    _tracksChangedController.add(null);
  }

  /// Get a track by its ID
  Future<Track?> getTrackById(String id) async {
    _ensureInitialized();
    _log.fine('Getting track by ID: $id');

    final maps = await _database!.query(
      'tracks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Track.fromMap(maps.first);
  }

  /// Check if a track exists in the database
  Future<bool> trackExists(String id) async {
    _ensureInitialized();
    _log.fine('Checking if track exists: $id');

    final result = await _database!.query(
      'tracks',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// Get all tracks from the database
  ///
  /// [orderBy] - SQL ORDER BY clause (default: 'downloaded_at DESC')
  Future<List<Track>> getAllTracks({
    String orderBy = 'downloaded_at DESC',
  }) async {
    _ensureInitialized();
    _log.fine('Getting all tracks (orderBy: $orderBy)');

    final maps = await _database!.query('tracks', orderBy: orderBy);

    final tracks = maps.map((map) => Track.fromMap(map)).toList();
    _log.fine('Retrieved ${tracks.length} tracks');

    return tracks;
  }

  /// Delete a track from the database
  Future<void> deleteTrack(String id) async {
    _ensureInitialized();
    _log.fine('Deleting track: $id');

    final count = await _database!.delete(
      'tracks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count > 0) {
      _log.info('Track deleted: $id');
      // Notify listeners that tracks have changed
      _tracksChangedController.add(null);
    } else {
      _log.warning('Track not found for deletion: $id');
    }
  }

  /// Get the count of tracks in the database
  Future<int> getTrackCount() async {
    _ensureInitialized();

    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM tracks',
    );
    return result.first['count'] as int;
  }

  // ==================== DOWNLOAD TASK METHODS ====================

  /// Insert or replace a download task
  Future<void> insertDownloadTask(DownloadTask task) async {
    _ensureInitialized();
    _log.fine('Inserting download task: ${task.videoId}');
    await _database!.insert(
      'download_tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing download task
  Future<void> updateDownloadTask(DownloadTask task) async {
    _ensureInitialized();
    _log.fine('Updating download task: ${task.videoId}');
    await _database!.update(
      'download_tasks',
      task.toMap(),
      where: 'video_id = ?',
      whereArgs: [task.videoId],
    );
  }

  /// Get all download tasks ordered by started_at DESC
  Future<List<DownloadTask>> getAllDownloadTasks() async {
    _ensureInitialized();
    _log.fine('Getting all download tasks');
    final maps = await _database!.query(
      'download_tasks',
      orderBy: 'started_at DESC',
    );
    return maps.map((map) => DownloadTask.fromMap(map)).toList();
  }

  /// Get a single download task by video ID
  Future<DownloadTask?> getDownloadTask(String videoId) async {
    _ensureInitialized();
    final maps = await _database!.query(
      'download_tasks',
      where: 'video_id = ?',
      whereArgs: [videoId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DownloadTask.fromMap(maps.first);
  }

  /// Delete a download task
  Future<void> deleteDownloadTask(String videoId) async {
    _ensureInitialized();
    _log.fine('Deleting download task: $videoId');
    await _database!.delete(
      'download_tasks',
      where: 'video_id = ?',
      whereArgs: [videoId],
    );
  }

  /// Delete all completed download tasks
  Future<void> clearCompletedDownloadTasks() async {
    _ensureInitialized();
    _log.fine('Clearing completed download tasks');
    await _database!.delete(
      'download_tasks',
      where: 'status = ?',
      whereArgs: [DownloadStatus.completed.index],
    );
  }

  /// Close the database connection
  Future<void> close() async {
    await _tracksChangedController.close();

    if (_database != null) {
      await _database!.close();
      _database = null;
      _log.info('Database closed');
    }
  }

  /// Get the app's audio directory path
  ///
  /// Creates the directory if it doesn't exist.
  static Future<Directory> getAudioDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(appDir.path, 'audio'));

    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
      _log.fine('Created audio directory: ${audioDir.path}');
    }

    return audioDir;
  }

  /// Get the full path to an audio file
  static Future<String> getAudioFilePath(String fileName) async {
    final audioDir = await getAudioDirectory();
    return p.join(audioDir.path, fileName);
  }

  /// Get the app's thumbnails directory path
  ///
  /// Creates the directory if it doesn't exist.
  static Future<Directory> getThumbnailsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory(p.join(appDir.path, 'thumbnails'));

    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
      _log.fine('Created thumbnails directory: ${thumbDir.path}');
    }

    return thumbDir;
  }

  /// Get the full path to a thumbnail file
  static Future<String> getThumbnailFilePath(String fileName) async {
    final thumbDir = await getThumbnailsDirectory();
    return p.join(thumbDir.path, fileName);
  }

  // ==================== PLAYLIST METHODS ====================

  /// Create a new playlist
  Future<Playlist> createPlaylist(String name) async {
    _ensureInitialized();
    _log.fine('Creating playlist: $name');

    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
    );

    await _database!.insert(
      'playlists',
      playlist.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _log.info('Playlist created: ${playlist.name}');
    return playlist;
  }

  /// Get all playlists with their track counts
  Future<List<Playlist>> getAllPlaylists() async {
    _ensureInitialized();
    _log.fine('Getting all playlists');

    final maps = await _database!.rawQuery('''
      SELECT 
        p.id,
        p.name,
        p.created_at,
        COUNT(pt.track_id) as track_count
      FROM playlists p
      LEFT JOIN playlist_tracks pt ON p.id = pt.playlist_id
      GROUP BY p.id
      ORDER BY p.created_at DESC
    ''');

    final playlists = maps.map((map) => Playlist.fromMap(map)).toList();
    _log.fine('Retrieved ${playlists.length} playlists');
    return playlists;
  }

  /// Get a playlist by ID
  Future<Playlist?> getPlaylistById(String id) async {
    _ensureInitialized();
    _log.fine('Getting playlist by ID: $id');

    final maps = await _database!.rawQuery(
      '''
      SELECT 
        p.id,
        p.name,
        p.created_at,
        COUNT(pt.track_id) as track_count
      FROM playlists p
      LEFT JOIN playlist_tracks pt ON p.id = pt.playlist_id
      WHERE p.id = ?
      GROUP BY p.id
    ''',
      [id],
    );

    if (maps.isEmpty) {
      return null;
    }

    return Playlist.fromMap(maps.first);
  }

  /// Delete a playlist
  Future<void> deletePlaylist(String id) async {
    _ensureInitialized();
    _log.fine('Deleting playlist: $id');

    await _database!.delete('playlists', where: 'id = ?', whereArgs: [id]);

    _log.info('Playlist deleted: $id');
  }

  /// Add a track to a playlist
  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    _ensureInitialized();
    _log.fine('Adding track $trackId to playlist $playlistId');

    await _database!.insert(
      'playlist_tracks',
      {
        'playlist_id': playlistId,
        'track_id': trackId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore if already exists
    );

    _log.info('Track added to playlist');
  }

  /// Remove a track from a playlist
  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    _ensureInitialized();
    _log.fine('Removing track $trackId from playlist $playlistId');

    await _database!.delete(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
    );

    _log.info('Track removed from playlist');
  }

  /// Get all tracks in a playlist
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    _ensureInitialized();
    _log.fine('Getting tracks for playlist: $playlistId');

    final maps = await _database!.rawQuery(
      '''
      SELECT 
        t.id,
        t.title,
        t.author,
        t.duration_ms,
        t.file_path,
        t.file_size,
        t.bitrate_kbps,
        t.container,
        t.downloaded_at,
        t.thumbnail_url,
        t.thumbnail_path
      FROM tracks t
      INNER JOIN playlist_tracks pt ON t.id = pt.track_id
      WHERE pt.playlist_id = ?
      ORDER BY pt.added_at ASC
    ''',
      [playlistId],
    );

    final tracks = maps.map((map) => Track.fromMap(map)).toList();
    _log.fine('Retrieved ${tracks.length} tracks for playlist');
    return tracks;
  }

  /// Check if a track is in a playlist
  Future<bool> isTrackInPlaylist(String playlistId, String trackId) async {
    _ensureInitialized();
    _log.fine('Checking if track $trackId is in playlist $playlistId');

    final result = await _database!.query(
      'playlist_tracks',
      columns: ['playlist_id'],
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// Get all playlists that contain a specific track
  Future<List<String>> getPlaylistsForTrack(String trackId) async {
    _ensureInitialized();
    _log.fine('Getting playlists for track: $trackId');

    final maps = await _database!.query(
      'playlist_tracks',
      columns: ['playlist_id'],
      where: 'track_id = ?',
      whereArgs: [trackId],
    );

    return maps.map((map) => map['playlist_id'] as String).toList();
  }

  /// Search tracks by title or author
  Future<List<Track>> searchTracks(String query) async {
    _ensureInitialized();
    _log.fine('Searching tracks with query: $query');

    final searchPattern = '%$query%';
    final maps = await _database!.query(
      'tracks',
      where: 'title LIKE ? OR author LIKE ?',
      whereArgs: [searchPattern, searchPattern],
      orderBy: 'title ASC',
    );

    final tracks = maps.map((map) => Track.fromMap(map)).toList();
    _log.fine('Found ${tracks.length} tracks matching query');
    return tracks;
  }

  /// Get all tracks that are NOT in a specific playlist
  Future<List<Track>> getTracksNotInPlaylist(String playlistId) async {
    _ensureInitialized();
    _log.fine('Getting tracks not in playlist: $playlistId');

    final maps = await _database!.rawQuery(
      '''
      SELECT 
        t.id,
        t.title,
        t.author,
        t.duration_ms,
        t.file_path,
        t.file_size,
        t.bitrate_kbps,
        t.container,
        t.downloaded_at,
        t.thumbnail_url,
        t.thumbnail_path
      FROM tracks t
      WHERE t.id NOT IN (
        SELECT track_id FROM playlist_tracks WHERE playlist_id = ?
      )
      ORDER BY t.title ASC
    ''',
      [playlistId],
    );

    final tracks = maps.map((map) => Track.fromMap(map)).toList();
    _log.fine('Retrieved ${tracks.length} tracks not in playlist');
    return tracks;
  }

  /// Save waveform data for a track
  Future<void> saveWaveform({
    required String trackId,
    required List<double> amplitudes,
    required int samplesPerSecond,
    required int durationMs,
  }) async {
    _ensureInitialized();
    _log.fine('Saving waveform for track: $trackId');

    await _database!.insert('waveforms', {
      'track_id': trackId,
      'amplitudes': amplitudes.join(','),
      'samples_per_second': samplesPerSecond,
      'duration_ms': durationMs,
      'extracted_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _log.fine('Waveform saved for track: $trackId');
  }

  /// Load waveform data for a track
  Future<Map<String, dynamic>?> getWaveform(String trackId) async {
    _ensureInitialized();
    _log.fine('Loading waveform for track: $trackId');

    final results = await _database!.query(
      'waveforms',
      where: 'track_id = ?',
      whereArgs: [trackId],
    );

    if (results.isEmpty) {
      _log.fine('No waveform found for track: $trackId');
      return null;
    }

    _log.fine('Waveform found for track: $trackId');
    return results.first;
  }

  /// Check if waveform exists for a track
  Future<bool> hasWaveform(String trackId) async {
    _ensureInitialized();

    final results = await _database!.query(
      'waveforms',
      columns: ['track_id'],
      where: 'track_id = ?',
      whereArgs: [trackId],
      limit: 1,
    );

    return results.isNotEmpty;
  }
}
