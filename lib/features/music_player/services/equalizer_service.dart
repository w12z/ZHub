import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/eq_preset.dart';
import 'music_player_settings.dart';

class EqualizerService {
  static final EqualizerService instance = EqualizerService._();
  EqualizerService._();

  MusicPlayerSettings? _playerSettings;

  bool _enabled = false;
  final List<double> _gains = List.filled(EqPreset.bandCount, 0.0);
  bool _filterActive = false;
  String? _activePresetName;

  bool get isEnabled => _enabled;
  List<double> get gains => List.unmodifiable(_gains);
  String? get activePresetName => _activePresetName;

  void attachSettings(MusicPlayerSettings settings) {
    _playerSettings = settings;
  }

  static double _dbToGain(double db) {
    if (db <= -12) return 0.0;
    return pow(10, db / 20).clamp(0.0, 4.0).toDouble();
  }

  // ── Load from centralized settings ──

  Future<void> loadFromSettings() async {
    if (_playerSettings == null) return;
    _enabled = _playerSettings!.eqEnabled;
    _activePresetName = _playerSettings!.eqActivePreset;
    for (int i = 0; i < _playerSettings!.eqGains.length && i < EqPreset.bandCount; i++) {
      _gains[i] = _playerSettings!.eqGains[i].clamp(EqPreset.minGain, EqPreset.maxGain);
    }
    if (_enabled) {
      await setEnabled(true);
    }
  }

  // ── Filter control ──

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (enabled) {
      await _activateFilter();
    } else {
      await _deactivateFilter();
    }
    _playerSettings?.saveEqState(enabled);
  }

  Future<void> _activateFilter() async {
    if (_filterActive) return;
    try {
      final eq = SoLoud.instance.filters.equalizerFilter;
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
      SoLoud.instance.filters.equalizerFilter.deactivate();
    } catch (_) {}
    _filterActive = false;
  }

  // ── Band control ──

  Future<void> setBandGain(int band, double gainDb) async {
    if (band < 0 || band >= EqPreset.bandCount) return;
    _gains[band] = gainDb.clamp(EqPreset.minGain, EqPreset.maxGain);
    _activePresetName = 'Custom';
    await _applyBandGain(band);
    _playerSettings?.saveEqGains(_gains);
    _playerSettings?.saveEqPresetName('Custom');
  }

  Future<void> applyGains(List<double> gains) async {
    for (int i = 0; i < gains.length && i < EqPreset.bandCount; i++) {
      _gains[i] = gains[i].clamp(EqPreset.minGain, EqPreset.maxGain);
    }
    await _applyAllGains();
    _playerSettings?.saveEqGains(_gains);
  }

  Future<void> _applyBandGain(int band) async {
    if (!_filterActive || !_enabled) return;
    try {
      final eq = SoLoud.instance.filters.equalizerFilter;
      final value = _dbToGain(_gains[band]);
      _setBandValue(eq, band, value);
    } catch (_) {}
  }

  Future<void> _applyAllGains() async {
    if (!_filterActive || !_enabled) return;
    try {
      final eq = SoLoud.instance.filters.equalizerFilter;
      for (int i = 0; i < EqPreset.bandCount; i++) {
        _setBandValue(eq, i, _dbToGain(_gains[i]));
      }
    } catch (_) {}
  }

  void _setBandValue(dynamic eq, int band, double value) {
    switch (band) {
      case 0: eq.band1.value = value; break;
      case 1: eq.band2.value = value; break;
      case 2: eq.band3.value = value; break;
      case 3: eq.band4.value = value; break;
      case 4: eq.band5.value = value; break;
      case 5: eq.band6.value = value; break;
      case 6: eq.band7.value = value; break;
      case 7: eq.band8.value = value; break;
    }
  }

  // ── Presets ──

  Future<void> applyPreset(EqPreset preset) async {
    _activePresetName = preset.name;
    await applyGains(preset.gains);
    _playerSettings?.saveEqPresetName(preset.name);
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
    _playerSettings?.saveEqGains(_gains);
    _playerSettings?.saveEqPresetName('Flat');
  }

  void dispose() {
    _deactivateFilter();
  }
}
