import 'package:sqflite/sqflite.dart';

class SettingsRepository {
  Database? _db;

  void attach(Database db) {
    _db = db;
  }

  Database get _ensureDb {
    if (_db == null) throw StateError('SettingsRepository not attached to a database');
    return _db!;
  }

  Future<String?> get(String key) async {
    final rows = await _ensureDb.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    await _ensureDb.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final v = await get(key);
    if (v == null) return defaultValue;
    return v == 'true';
  }

  Future<void> setBool(String key, bool value) async {
    await set(key, value ? 'true' : 'false');
  }

  Future<int?> getInt(String key) async {
    final v = await get(key);
    if (v == null) return null;
    return int.tryParse(v);
  }

  Future<void> setInt(String key, int value) async {
    await set(key, value.toString());
  }

  Future<double?> getDouble(String key) async {
    final v = await get(key);
    if (v == null) return null;
    return double.tryParse(v);
  }

  Future<void> setDouble(String key, double value) async {
    await set(key, value.toString());
  }
}
