import 'dart:async';
import 'package:flutter/services.dart';

class AudioSessionMonitor {
  static final AudioSessionMonitor instance = AudioSessionMonitor._();
  AudioSessionMonitor._();

  static const _channel = MethodChannel('com.filehub/audio_focus');

  final _otherAudioController = StreamController<bool>.broadcast();
  Stream<bool> get onOtherAudioChanged => _otherAudioController.stream;

  bool _otherAudioPlaying = false;
  bool get isOtherAudioPlaying => _otherAudioPlaying;

  Timer? _pollTimer;

  void start() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final hasOther = await _channel.invokeMethod<bool>('hasOtherAudio') ?? false;
      if (hasOther != _otherAudioPlaying) {
        _otherAudioPlaying = hasOther;
        _otherAudioController.add(hasOther);
      }
    } catch (_) {
      // Channel not implemented on this platform — graceful fallback
    }
  }

  Future<bool> hasOtherAudio() async {
    try {
      return await _channel.invokeMethod<bool>('hasOtherAudio') ?? false;
    } catch (_) {
      return false;
    }
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void dispose() {
    stop();
    _otherAudioController.close();
  }
}
