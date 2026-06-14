import 'package:flutter/material.dart';
import 'feature_interface.dart';
import 'key_value_store.dart';

/// 全局模块注册表，管理所有 feature 的生命周期，并把启用状态持久化。
class FeatureRegistry extends ChangeNotifier {
  static final FeatureRegistry instance = FeatureRegistry._();
  factory FeatureRegistry() => instance;
  FeatureRegistry._();

  static const _prefsKey = 'feature_registry.enabled';

  final Map<String, AppFeature> _features = {};
  final Set<String> _enabledFeatures = {};
  bool _restored = false;

  /// 在 register() 之前调用，从持久化中读取上次的启用集合。
  /// 若未存储过则返回 null，调用方应继续使用各模块的 enabledByDefault。
  Future<void> restore() async {
    final stored = KeyValueStore.instance.getStringList(_prefsKey);
    if (stored != null) {
      _enabledFeatures
        ..clear()
        ..addAll(stored);
    }
    _restored = true;
  }

  void register(AppFeature feature) {
    _features[feature.id] = feature;
    if (!_restored && feature.enabledByDefault) {
      _enabledFeatures.add(feature.id);
    }
  }

  Future<void> _persist() async {
    await KeyValueStore.instance.setStringList(
      _prefsKey,
      _enabledFeatures.toList(),
    );
  }

  Future<void> enable(String id) async {
    if (!_features.containsKey(id) || _enabledFeatures.contains(id)) return;
    final feature = _features[id]!;
    await feature.init();
    _enabledFeatures.add(id);
    await _persist();
    notifyListeners();
  }

  Future<void> disable(String id) async {
    if (!_features.containsKey(id) || !_enabledFeatures.contains(id)) return;
    final feature = _features[id]!;
    await feature.dispose();
    _enabledFeatures.remove(id);
    await _persist();
    notifyListeners();
  }

  Future<void> uninstall(String id) async {
    if (!_features.containsKey(id)) return;
    await disable(id);
    _features.remove(id);
    notifyListeners();
  }

  bool isEnabled(String id) => _enabledFeatures.contains(id);
  bool isRegistered(String id) => _features.containsKey(id);

  List<AppFeature> get enabledFeatures =>
      _features.values.where((f) => _enabledFeatures.contains(f.id)).toList();

  List<AppFeature> get allFeatures => _features.values.toList();
}
