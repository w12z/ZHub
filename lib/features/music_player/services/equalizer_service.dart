import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/eq_preset.dart';
import 'settings_repository.dart';

class EqualizerService {
  static final EqualizerService instance = EqualizerService._();
  EqualizerService._();

  SettingsRepository? _settings;

  bool _enabled = false;
  final List<double> _gains = List.filled(EqPreset.bandCount, 0.0);
  bool _filterActive = false;
  String? _activePresetName;

  bool get isEnabled => _enabled;
  List<double> get gains => List.unmodifiable(_gains);
  String? get activePresetName => _activePresetName;

  void attachSettings(SettingsRepository settings) {
    _settings = settings;
  }

  static double _dbToGain(double db) {
    if (db <= -12) return 0.0;
    return pow(10, db / 20).clamp(0.0, 4.0).toDouble();
  }

  // ── Persistence ──

  Future<void> loadFromSettings() async {
    if (_settings == null) return;
    final enabled = await _settings!.getBool('eq_enabled');
    final presetName = await _settings!.get('eq_active_preset');
    final gainsJson = await _settings!.get('eq_gains');

    if (gainsJson != null) {
      try {
        final list = (jsonDecode(gainsJson) as List).map((e) => (e as num).toDouble()).toList();
        for (int i = 0; i < list.length && i < EqPreset.bandCount; i++) {
          _gains[i] = list[i].clamp(EqPreset.minGain, EqPreset.maxGain);
        }
      } catch (_) {}
    }

    _activePresetName = presetName ?? 'Flat';

    if (enabled) {
      await setEnabled(true);
    }
  }

  Future<void> _saveToSettings() async {
    if (_settings == null) return;
    await _settings!.setBool('eq_enabled', _enabled);
    await _settings!.set('eq_active_preset', _activePresetName ?? 'Flat');
    await _settings!.set('eq_gains', jsonEncode(_gains));
  }

  // ── Filter control ──

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (enabled) {
      await _activateFilter();
    } else {
      await _deactivateFilter();
    }
    await _saveToSettings();
  }

  Future<void> _activateFilter() async {
    if (_filterActive) return;
    try {
      final eq = SoLoud.instance.filters.parametricEqFilter;
      eq.numBands.value = EqPreset.bandCount.toDouble();
      eq.activate();
      _filterActive = true;
      await _applyAllGains();
    } catch (e) {
      debugPrint('[EQ] activate failed: $e');
    }
  }

  Future<void> _deactivateFilter() async {
    if (!_filterActive) return;
    try {
      SoLoud.instance.filters.parametricEqFilter.deactivate();
    } catch (_) {}
    _filterActive = false;
  }

  // ── Band control ──

  Future<void> setBandGain(int band, double gainDb) async {
    if (band < 0 || band >= EqPreset.bandCount) return;
    _gains[band] = gainDb.clamp(EqPreset.minGain, EqPreset.maxGain);
    _activePresetName = 'Custom';
    await _applyBandGain(band);
    await _saveToSettings();
  }

  Future<void> applyGains(List<double> gains) async {
    for (int i = 0; i < gains.length && i < EqPreset.bandCount; i++) {
      _gains[i] = gains[i].clamp(EqPreset.minGain, EqPreset.maxGain);
    }
    await _applyAllGains();
    await _saveToSettings();
  }

  Future<void> _applyBandGain(int band) async {
    if (!_filterActive || !_enabled) return;
    try {
      SoLoud.instance.filters.parametricEqFilter
          .bandGain(band)
          .value = _dbToGain(_gains[band]);
    } catch (_) {}
  }

  Future<void> _applyAllGains() async {
    if (!_filterActive || !_enabled) return;
    try {
      final eq = SoLoud.instance.filters.parametricEqFilter;
      for (int i = 0; i < EqPreset.bandCount; i++) {
        eq.bandGain(i).value = _dbToGain(_gains[i]);
      }
    } catch (_) {}
  }

  // ── Presets ──

  Future<void> applyPreset(EqPreset preset) async {
    _activePresetName = preset.name;
    await applyGains(preset.gains);
  }

  Future<void> applyPresetByName(String name, List<EqPreset> allPresets) async {
    final match = allPresets.where((p) => p.name == name).firstOrNull;
    if (match != null) {
      await applyPreset(match);
    }
  }

  Future<void> reset() async {
    for (int i = 0; i < EqPreset.bandCount; i++) {
      _gains[i] = 0.0;
    }
    _activePresetName = 'Flat';
    await _applyAllGains();
    await _saveToSettings();
  }

  void dispose() {
    _deactivateFilter();
  }
}
