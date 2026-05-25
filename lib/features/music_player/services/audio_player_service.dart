import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/music_track.dart';
import 'audio_session_monitor.dart';

enum PlayMode { sequential, shuffle, repeatOne, repeatAll }

enum AudioInterruptMode { pause, duck }

class AudioPlayerService {
  AudioSource? _currentSource;
  SoundHandle? _currentHandle;
  Timer? _pollTimer;

  final _queue = <MusicTrack>[];
  var _currentIndex = -1;
  var _playMode = PlayMode.sequential;
  var _interruptMode = AudioInterruptMode.pause;
  List<int> _shuffleOrder = [];
  int _shufflePosition = -1;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _isPlaying = false;

  final _playbackStateController = StreamController<PlaybackState>.broadcast();
  Stream<PlaybackState> get playbackState => _playbackStateController.stream;

  final _currentIndexController = StreamController<int?>.broadcast();
  Stream<int?> get currentIndex => _currentIndexController.stream;

  final _positionController = StreamController<Duration>.broadcast();
  Stream<Duration> get position => _positionController.stream;

  final _durationController = StreamController<Duration>.broadcast();
  Stream<Duration> get duration => _durationController.stream;

  final _volumeController = StreamController<double>.broadcast();
  Stream<double> get volume => _volumeController.stream;

  final _playModeController = StreamController<PlayMode>.broadcast();
  Stream<PlayMode> get playMode => _playModeController.stream;

  final _interruptModeController = StreamController<AudioInterruptMode>.broadcast();
  Stream<AudioInterruptMode> get interruptModeStream => _interruptModeController.stream;

  final _queueController = StreamController<List<MusicTrack>>.broadcast();
  Stream<List<MusicTrack>> get queue => _queueController.stream;

  MusicTrack? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;

  List<MusicTrack> get currentQueue => List.unmodifiable(_queue);
  PlayMode get currentPlayMode => _playMode;
  AudioInterruptMode get currentInterruptMode => _interruptMode;
  int get currentTrackIndex => _currentIndex;
  Duration get currentPosition => _position;
  Duration get currentDuration => _duration;

  StreamSubscription? _otherAudioSub;

  AudioPlayerService() {
    _startPolling();
    AudioSessionMonitor.instance.start();
    _otherAudioSub = AudioSessionMonitor.instance.onOtherAudioChanged.listen((otherPlaying) {
      if (_currentHandle == null) return;
      if (otherPlaying) {
        _onOtherAudioStarted();
      } else {
        _onOtherAudioStopped();
      }
    });
  }

  bool _otherAudioPlaying = false;
  bool _userPaused = false;

  Timer? _fadeTimer;

  void _fadeVolume(double target, {int steps = 20, int intervalMs = 15}) {
    _fadeTimer?.cancel();
    if (_currentHandle == null) return;
    final startVol = SoLoud.instance.getVolume(_currentHandle!);
    final delta = (target - startVol) / steps;
    var remaining = steps;

    _fadeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      remaining--;
      if (remaining <= 0 || _currentHandle == null) {
        SoLoud.instance.setVolume(_currentHandle!, target);
        timer.cancel();
        _fadeTimer = null;
        return;
      }
      final vol = startVol + delta * (steps - remaining);
      SoLoud.instance.setVolume(_currentHandle!, vol);
    });
  }

  void _onOtherAudioStarted() {
    _otherAudioPlaying = true;
    if (_userPaused) return;
    switch (_interruptMode) {
      case AudioInterruptMode.pause:
        if (_isPlaying) {
          SoLoud.instance.pauseSwitch(_currentHandle!);
          _isPlaying = false;
          _playbackStateController.add(PlaybackState.paused);
        }
        break;
      case AudioInterruptMode.duck:
        _fadeVolume(_volume * 0.2);
        break;
    }
  }

  void _onOtherAudioStopped() {
    _otherAudioPlaying = false;
    if (_userPaused || _currentHandle == null) return;
    if (_interruptMode == AudioInterruptMode.duck) {
      _fadeVolume(_volume);
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_currentHandle == null) return;
      try {
        final actuallyPaused = SoLoud.instance.getPause(_currentHandle!);

        // In duck mode with other audio, unpause (unless user manually paused)
        if (actuallyPaused && _interruptMode == AudioInterruptMode.duck && _otherAudioPlaying && !_userPaused) {
          SoLoud.instance.setPause(_currentHandle!, false);
        }

        // Sync UI pause state (only for pause mode)
        if (actuallyPaused && _isPlaying && _interruptMode == AudioInterruptMode.pause) {
          _isPlaying = false;
          _playbackStateController.add(PlaybackState.paused);
        } else if (!actuallyPaused && !_isPlaying && !_otherAudioPlaying) {
          _isPlaying = true;
          _playbackStateController.add(PlaybackState.playing);
        }

        if (!actuallyPaused) {
          final pos = SoLoud.instance.getPosition(_currentHandle!);
          if (pos != _position) {
            _position = pos;
            _positionController.add(pos);
          }
          // Detect end of track
          if (_duration > Duration.zero && pos >= _duration - const Duration(milliseconds: 200)) {
            _onTrackComplete();
          }
        }
      } catch (_) {}
    });
  }

  void _onTrackComplete() {
    _isPlaying = false;
    _playbackStateController.add(PlaybackState.stopped);
    final next = _nextIndex;
    if (next == -1) {
      _currentIndex = -1;
      _currentIndexController.add(null);
    } else {
      _loadAndPlayTrack(next);
    }
  }

  // ── Player control ──

  Future<void> play() async {
    _userPaused = false;
    if (_isPlaying) return;
    if (_currentHandle != null) {
      SoLoud.instance.pauseSwitch(_currentHandle!);
      _isPlaying = true;
      _playbackStateController.add(PlaybackState.playing);
    } else if (_queue.isNotEmpty) {
      await _loadAndPlayTrack(_effectiveIndex);
    }
  }

  Future<void> pause() async {
    if (_currentHandle == null) return;
    _userPaused = true;
    SoLoud.instance.pauseSwitch(_currentHandle!);
    _isPlaying = false;
    _playbackStateController.add(PlaybackState.paused);
  }

  Future<void> stop() async {
    _cleanupCurrent();
    _currentIndex = -1;
    _shufflePosition = -1;
    _currentIndexController.add(null);
    _playbackStateController.add(PlaybackState.stopped);
  }

  Future<void> seek(Duration pos) async {
    if (_currentHandle == null) return;
    SoLoud.instance.seek(_currentHandle!, pos);
    _position = pos;
    _positionController.add(pos);
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    if (_currentHandle != null) {
      SoLoud.instance.setVolume(_currentHandle!, _volume);
    }
    _volumeController.add(_volume);
  }

  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    final nextIdx = _nextIndex;
    if (nextIdx == -1) return;
    await _loadAndPlayTrack(nextIdx);
  }

  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    final prevIdx = _previousIndex;
    if (prevIdx == -1) return;
    await _loadAndPlayTrack(prevIdx);
  }

  // ── Queue management ──

  Future<void> loadQueue(List<MusicTrack> tracks, {int startIndex = 0}) async {
    _queue.clear();
    _queue.addAll(tracks);
    _rebuildShuffleOrder();
    _queueController.add(currentQueue);

    if (tracks.isNotEmpty) {
      await _loadAndPlayTrack(startIndex.clamp(0, tracks.length - 1));
    }
  }

  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _loadAndPlayTrack(index);
  }

  void moveTrack(int from, int to) {
    if (from < 0 || from >= _queue.length || to < 0 || to >= _queue.length) return;
    final track = _queue.removeAt(from);
    _queue.insert(to, track);
    if (_currentIndex == from) {
      _currentIndex = to;
    } else if (from < _currentIndex && to >= _currentIndex) {
      _currentIndex--;
    } else if (from > _currentIndex && to <= _currentIndex) {
      _currentIndex++;
    }
    _rebuildShuffleOrder();
    _queueController.add(currentQueue);
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_queue.isEmpty) {
        _currentIndex = -1;
        _currentIndexController.add(null);
        _cleanupCurrent();
      } else if (_currentIndex >= _queue.length) {
        _loadAndPlayTrack(0);
      } else {
        _loadAndPlayTrack(_currentIndex);
      }
      _rebuildShuffleOrder();
      _queueController.add(currentQueue);
      return;
    }
    _rebuildShuffleOrder();
    _queueController.add(currentQueue);
  }

  void addToQueue(MusicTrack track) {
    _queue.add(track);
    _rebuildShuffleOrder();
    _queueController.add(currentQueue);
  }

  void insertNext(MusicTrack track) {
    final insertAt = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertAt, track);
    _rebuildShuffleOrder();
    _queueController.add(currentQueue);
  }

  // ── Play mode ──

  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    _playModeController.add(mode);
    if (mode == PlayMode.shuffle) {
      _rebuildShuffleOrder();
      _shufflePosition = _shuffleOrder.indexOf(_currentIndex);
    }
  }

  Future<void> setInterruptMode(AudioInterruptMode mode) async {
    _interruptMode = mode;
    _interruptModeController.add(mode);
  }

  // ── Internal ──

  int get _effectiveIndex {
    if (_playMode == PlayMode.shuffle && _shuffleOrder.isNotEmpty) {
      return _shuffleOrder[_shufflePosition.clamp(0, _shuffleOrder.length - 1)];
    }
    return _currentIndex.clamp(0, _queue.length - 1);
  }

  int get _nextIndex {
    if (_queue.isEmpty) return -1;
    if (_playMode == PlayMode.repeatOne) return _currentIndex;
    if (_playMode == PlayMode.shuffle && _shuffleOrder.isNotEmpty) {
      _shufflePosition++;
      if (_shufflePosition >= _shuffleOrder.length) {
        _rebuildShuffleOrder();
        _shufflePosition = 0;
      }
      return _shuffleOrder[_shufflePosition];
    }
    final next = _currentIndex + 1;
    if (next >= _queue.length) {
      return _playMode == PlayMode.repeatAll ? 0 : -1;
    }
    return next;
  }

  int get _previousIndex {
    if (_queue.isEmpty) return -1;
    if (_playMode == PlayMode.shuffle && _shuffleOrder.isNotEmpty) {
      _shufflePosition--;
      if (_shufflePosition < 0) {
        _shufflePosition = _shuffleOrder.length - 1;
      }
      return _shuffleOrder[_shufflePosition];
    }
    if (_position.inSeconds > 3) return _currentIndex;
    final prev = _currentIndex - 1;
    return prev < 0
        ? (_playMode == PlayMode.repeatAll ? _queue.length - 1 : _currentIndex)
        : prev;
  }

  void _rebuildShuffleOrder() {
    _shuffleOrder = List.generate(_queue.length, (i) => i);
    _shuffleOrder.shuffle(Random());
    _shufflePosition = _shuffleOrder.indexOf(_currentIndex);
  }

  void _cleanupCurrent() {
    if (_currentHandle != null) {
      SoLoud.instance.stop(_currentHandle!);
      _currentHandle = null;
    }
    if (_currentSource != null) {
      SoLoud.instance.disposeSource(_currentSource!);
      _currentSource = null;
    }
    _isPlaying = false;
  }

  Future<void> _loadAndPlayTrack(int index) async {
    _cleanupCurrent();
    _currentIndex = index;
    _currentIndexController.add(index);
    _playbackStateController.add(PlaybackState.loading);

    final path = _queue[index].path;
    try {
      _currentSource = await SoLoud.instance.loadFile(path);
      _duration = SoLoud.instance.getLength(_currentSource!);
      _durationController.add(_duration);
      _currentHandle = SoLoud.instance.play(_currentSource!, volume: _volume);
      _isPlaying = true;
      _playbackStateController.add(PlaybackState.playing);
    } catch (e) {
      debugPrint('[AudioPlayer] Failed to load: $path, error: $e');
      _playbackStateController.add(PlaybackState.stopped);
      final next = _nextIndex;
      if (next != -1 && next != index) {
        _loadAndPlayTrack(next);
      }
    }
  }

  Future<void> dispose() async {
    _pollTimer?.cancel();
    _otherAudioSub?.cancel();
    _fadeTimer?.cancel();
    _cleanupCurrent();
    await _playbackStateController.close();
    await _currentIndexController.close();
    await _positionController.close();
    await _durationController.close();
    await _volumeController.close();
    await _playModeController.close();
    await _interruptModeController.close();
    await _queueController.close();
  }
}

enum PlaybackState { playing, paused, loading, stopped }
