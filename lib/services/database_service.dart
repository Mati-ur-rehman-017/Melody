import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/track.dart';

/// Logger instance for the database service
final Logger _log = Logger('DatabaseService');

/// Database version for migrations
const int _databaseVersion = 2;

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
}
