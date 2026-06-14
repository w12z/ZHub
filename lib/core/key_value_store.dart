import 'package:shared_preferences/shared_preferences.dart';

/// 简单的键值存储抽象。封装 SharedPreferences，
/// 让所有模块通过统一接口持久化轻量配置。
class KeyValueStore {
  static final KeyValueStore instance = KeyValueStore._();
  KeyValueStore._();

  SharedPreferences? _prefs;
  bool get isReady => _prefs != null;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String? getString(String key) => _prefs?.getString(key);
  bool? getBool(String key) => _prefs?.getBool(key);
  int? getInt(String key) => _prefs?.getInt(key);
  List<String>? getStringList(String key) => _prefs?.getStringList(key);

  Future<bool> setString(String key, String value) async =>
      await _prefs?.setString(key, value) ?? false;
  Future<bool> setBool(String key, bool value) async =>
      await _prefs?.setBool(key, value) ?? false;
  Future<bool> setInt(String key, int value) async =>
      await _prefs?.setInt(key, value) ?? false;
  Future<bool> setStringList(String key, List<String> value) async =>
      await _prefs?.setStringList(key, value) ?? false;

  Future<bool> remove(String key) async =>
      await _prefs?.remove(key) ?? false;
}
