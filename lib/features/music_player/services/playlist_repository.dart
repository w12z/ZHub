import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/playlist.dart';
import '../models/eq_preset.dart';
import 'settings_repository.dart';

class PlaylistRepository {
  static final PlaylistRepository instance = PlaylistRepository._();
  PlaylistRepository._();

  Database? _db;
  final SettingsRepository settings = SettingsRepository();

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    settings.attach(_db!);
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'file_hub_music.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_tracks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        track_path TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE eq_presets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        gains_json TEXT NOT NULL,
        is_builtin INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_playlist_tracks_playlist ON playlist_tracks(playlist_id)',
    );
    await db.execute(
      'CREATE INDEX idx_playlist_tracks_order ON playlist_tracks(playlist_id, sort_order)',
    );

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _insertDefaultEqPresets(db);
  }

  Future<void> _insertDefaultEqPresets(Database db) async {
    for (final preset in EqPreset.builtInPresets) {
      await db.insert('eq_presets', {
        'name': preset.name,
        'gains_json': jsonEncode(preset.gains),
        'is_builtin': 1,
        'created_at': preset.createdAt.toIso8601String(),
      });
    }
  }

  // ── Playlist CRUD ──

  Future<Playlist> create(String name) async {
    final database = await db;
    final now = DateTime.now().toIso8601String();
    final id = await database.insert('playlists', {
      'name': name,
      'created_at': now,
      'updated_at': now,
    });
    return Playlist(
      id: id,
      name: name,
      trackPaths: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> delete(int id) async {
    final database = await db;
    await database.delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [id]);
    await database.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> rename(int id, String newName) async {
    final database = await db;
    await database.update(
      'playlists',
      {'name': newName, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addTrack(int playlistId, String trackPath) async {
    final database = await db;
    final maxOrder = Sqflite.firstIntValue(await database.rawQuery(
      'SELECT MAX(sort_order) FROM playlist_tracks WHERE playlist_id = ?',
      [playlistId],
    ));
    final nextOrder = (maxOrder ?? -1) + 1;
    await database.insert('playlist_tracks', {
      'playlist_id': playlistId,
      'track_path': trackPath,
      'sort_order': nextOrder,
    });
    await database.update(
      'playlists',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<void> removeTrack(int playlistId, String trackPath) async {
    final database = await db;
    await database.delete(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_path = ?',
      whereArgs: [playlistId, trackPath],
    );
    await database.update(
      'playlists',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<void> reorderTracks(int playlistId, int oldIndex, int newIndex) async {
    final database = await db;
    final tracks = await database.query(
      'playlist_tracks',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'sort_order ASC',
    );

    final ids = tracks.map((t) => t['id'] as int).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);

    for (int i = 0; i < ids.length; i++) {
      await database.update(
        'playlist_tracks',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [ids[i]],
      );
    }

    await database.update(
      'playlists',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<List<Playlist>> getAll() async {
    final database = await db;
    final rows = await database.query('playlists', orderBy: 'updated_at DESC');
    final playlists = <Playlist>[];
    for (final row in rows) {
      final tracks = await database.query(
        'playlist_tracks',
        where: 'playlist_id = ?',
        whereArgs: [row['id']],
        orderBy: 'sort_order ASC',
      );
      final trackPaths = tracks.map((t) => t['track_path'] as String).toList();
      playlists.add(Playlist(
        id: row['id'] as int,
        name: row['name'] as String,
        trackPaths: trackPaths,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      ));
    }
    return playlists;
  }

  Future<Playlist?> getById(int id) async {
    final database = await db;
    final rows = await database.query('playlists', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final tracks = await database.query(
      'playlist_tracks',
      where: 'playlist_id = ?',
      whereArgs: [id],
      orderBy: 'sort_order ASC',
    );
    final trackPaths = tracks.map((t) => t['track_path'] as String).toList();
    return Playlist(
      id: row['id'] as int,
      name: row['name'] as String,
      trackPaths: trackPaths,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  // ── EQ Preset CRUD ──

  Future<List<EqPreset>> getAllEqPresets() async {
    final database = await db;
    final rows = await database.query('eq_presets', orderBy: 'is_builtin DESC, id ASC');
    return rows.map((row) => EqPreset.fromJson(row)).toList();
  }

  Future<int> saveEqPreset(String name, List<double> gains) async {
    final database = await db;
    return database.insert('eq_presets', {
      'name': name,
      'gains_json': jsonEncode(gains),
      'is_builtin': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateEqPreset(int id, String name, List<double> gains) async {
    final database = await db;
    await database.update(
      'eq_presets',
      {
        'name': name,
        'gains_json': jsonEncode(gains),
      },
      where: 'id = ? AND is_builtin = 0',
      whereArgs: [id],
    );
  }

  Future<void> deleteEqPreset(int id) async {
    final database = await db;
    await database.delete(
      'eq_presets',
      where: 'id = ? AND is_builtin = 0',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
