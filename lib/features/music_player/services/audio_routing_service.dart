import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'settings_repository.dart';

class AudioDevice {
  final int id;
  final String name;
  final bool isActive;

  const AudioDevice({
    required this.id,
    required this.name,
    this.isActive = false,
  });
}

class AudioRoutingService {
  static final AudioRoutingService instance = AudioRoutingService._();
  AudioRoutingService._();

  SettingsRepository? _settings;
  final _deviceChangedController = StreamController<AudioDevice?>.broadcast();
  Timer? _pollTimer;
  int? _activeDeviceId;

  Stream<AudioDevice?> get onDeviceChanged => _deviceChangedController.stream;

  void attachSettings(SettingsRepository settings) {
    _settings = settings;
  }

  Future<void> loadFromSettings() async {
    if (_settings == null) return;
    final deviceId = await _settings!.getInt('output_device_id');
    if (deviceId != null) {
      _activeDeviceId = deviceId;
    }
  }

  Future<void> _saveToSettings() async {
    if (_settings == null) return;
    if (_activeDeviceId != null) {
      await _settings!.setInt('output_device_id', _activeDeviceId!);
    }
  }

  void startMonitoring() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkDeviceChanges();
    });
  }

  void _checkDeviceChanges() {
    try {
      final devices = listDevices();
      final active = devices.where((d) => d.isActive).firstOrNull;
      if (active?.id != _activeDeviceId) {
        _activeDeviceId = active?.id;
        _deviceChangedController.add(active);
      }
    } catch (_) {}
  }

  List<AudioDevice> listDevices() {
    final playbackDevices = SoLoud.instance.listPlaybackDevices();
    // Initialize active device from system default on first call
    if (_activeDeviceId == null) {
      final defaultDevice = playbackDevices.firstWhere(
        (d) => d.isDefault,
        orElse: () => playbackDevices.first,
      );
      _activeDeviceId = defaultDevice.id;
    }
    return playbackDevices.map((d) {
      return AudioDevice(
        id: d.id,
        name: d.name,
        isActive: d.id == _activeDeviceId,
      );
    }).toList();
  }

  Future<void> switchToDevice(int deviceId) async {
    final devices = SoLoud.instance.listPlaybackDevices();
    final target = devices.cast<PlaybackDevice?>().firstWhere(
      (d) => d?.id == deviceId,
      orElse: () => null,
    );
    if (target != null) {
      _activeDeviceId = deviceId;
      SoLoud.instance.changeDevice(newDevice: target);
      await _saveToSettings();
      debugPrint('[AudioRouting] Switched to: ${target.name} (id: $deviceId)');
    }
  }

  int? get activeDeviceId => _activeDeviceId;

  void stopMonitoring() {
    _pollTimer?.cancel();
  }

  void dispose() {
    stopMonitoring();
    _deviceChangedController.close();
  }
}
