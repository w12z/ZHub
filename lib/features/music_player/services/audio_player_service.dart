import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/music_track.dart';
import 'package:flutter/services.dart';


enum PlayMode { sequential, shuffle, repeatOne, repeatPlaylist, repeatAll }

enum AudioInterruptMode { pause, duck }

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService instance = AudioPlayerService._();
  AudioPlayerService._() {
    _audioSessionStarted = true;
    _startUnifiedPolling();
  }

  static const _audioChannel = MethodChannel('com.filehub/audio_focus');
  bool _audioSessionStarted = false;

  Future<bool> _hasOtherAudio() async {
    if (!_audioSessionStarted) return false;
    try {
      return await _audioChannel.invokeMethod<bool>('hasOtherAudio') ?? false;
    } catch (_) {
      return false;
    }
  }

  AudioSource? _currentSource;
  SoundHandle? _currentHandle;

  final _queuePlaylists = <QueuePlaylist>[];
  var _activePlaylistIndex = -1;
  QueuePlaylist? get _activePlaylist =>
      _activePlaylistIndex >= 0 && _activePlaylistIndex < _queuePlaylists.length
          ? _queuePlaylists[_activePlaylistIndex]
          : null;
  List<MusicTrack> get _queue => _activePlaylist?.tracks ?? <MusicTrack>[];
  int get _currentIndex => _activePlaylist?.currentTrackIndex ?? -1;
  set _currentIndex(int value) {
    if (_activePlaylist != null) _activePlaylist!.currentTrackIndex = value;
  }

  var _playMode = PlayMode.repeatPlaylist;
  var _interruptMode = AudioInterruptMode.pause;
  List<int> _shuffleOrder = [];
  int _shufflePosition = -1;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _isPlaying = false;

  // ── Public state (same API as old PlayerStateProvider) ──

  MusicTrack? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;

  List<MusicTrack> get queue => List.unmodifiable(_queue);
  List<QueuePlaylist> get queuePlaylists => List.unmodifiable(_queuePlaylists);
  int get activePlaylistIndex => _activePlaylistIndex;
  PlayMode get playMode => _playMode;
  AudioInterruptMode get interruptMode => _interruptMode;
  int? get currentIndex => _currentIndex >= 0 ? _currentIndex : null;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  bool get isPlaying => _isPlaying;

  double get positionFraction =>
      _duration.inMilliseconds > 0
          ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

  // ── Unified timer + audio session ──

  Timer? _pollTimer;
  bool _otherAudioPlaying = false;
  bool _userPaused = false;
  int _tickCount = 0;
  Timer? _fadeTimer;

  void _startUnifiedPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _tickCount++;

      // Every tick: position tracking + pause sync
      _pollPosition();

      // Every 2 ticks (500ms): audio session check
      if (_tickCount % 2 == 0) {
        _checkAudioSession();
      }

      // Every 8 ticks (2000ms): device change check (delegated to AudioRoutingService)
      // Device changes are event-driven via switchToDevice(), so no polling needed
    });
  }

  void _pollPosition() {
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
        notifyListeners();
      } else if (!actuallyPaused && !_isPlaying && !_otherAudioPlaying) {
        _isPlaying = true;
        notifyListeners();
      }

      if (!actuallyPaused) {
        final pos = SoLoud.instance.getPosition(_currentHandle!);
        if (pos != _position) {
          _position = pos;
          notifyListeners();
        }
        // Periodic position save for playlist switching
        if (_tickCount % 20 == 0 && _activePlaylist != null) {
          _activePlaylist!.savedPosition = _position;
        }
        // Detect end of track
        if (_duration > Duration.zero && pos >= _duration - const Duration(milliseconds: 200)) {
          _onTrackComplete();
        }
      }
    } catch (_) {}
  }

  void _checkAudioSession() {
    try {
      _hasOtherAudio().then((hasOther) {
        if (hasOther != _otherAudioPlaying) {
          _otherAudioPlaying = hasOther;
          if (_currentHandle != null) {
            if (hasOther) {
              _onOtherAudioStarted();
            } else {
              _onOtherAudioStopped();
            }
          }
        }
      });
    } catch (_) {}
  }

  // ── Interrupt handling ──

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
          notifyListeners();
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

  // ── Player controls ──

  Future<void> play() async {
    _userPaused = false;
    if (_isPlaying) return;
    if (_currentHandle != null) {
      SoLoud.instance.pauseSwitch(_currentHandle!);
      _isPlaying = true;
      notifyListeners();
    } else if (_queue.isNotEmpty) {
      await _loadAndPlayTrack(_effectiveIndex);
    }
  }

  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  Future<void> pause() async {
    if (_currentHandle == null) return;
    _userPaused = true;
    SoLoud.instance.pauseSwitch(_currentHandle!);
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> stop() async {
    _cleanupCurrent();
    _activePlaylistIndex = -1;
    _queuePlaylists.clear();
    _shufflePosition = -1;
    notifyListeners();
  }

  Future<void> seek(Duration pos) async {
    if (_currentHandle == null) return;
    final maxSeek = _duration > const Duration(seconds: 1)
        ? _duration - const Duration(milliseconds: 500)
        : Duration.zero;
    Duration clamped = pos;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (clamped > maxSeek) clamped = maxSeek;
    try {
      SoLoud.instance.seek(_currentHandle!, clamped);
      _position = clamped;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    if (_currentHandle != null) {
      SoLoud.instance.setVolume(_currentHandle!, _volume);
    }
    notifyListeners();
  }

  void next() {
    if (_queue.isEmpty) return;
    final nextIdx = _nextIndex;
    if (nextIdx == -1) return;
    _loadAndPlayTrack(nextIdx);
  }

  void previous() {
    if (_queue.isEmpty) return;
    final prevIdx = _previousIndex;
    if (prevIdx == -1) return;
    _loadAndPlayTrack(prevIdx);
  }

  // ── Queue management ──

  Future<void> playQueue(List<MusicTrack> tracks, {int startIndex = 0}) async {
    _queuePlaylists.clear();
    final qp = QueuePlaylist(name: '所有音频', tracks: tracks);
    _queuePlaylists.add(qp);
    _activePlaylistIndex = 0;
    _rebuildShuffleOrder();
    notifyListeners();

    if (tracks.isNotEmpty) {
      await _loadAndPlayTrack(startIndex.clamp(0, tracks.length - 1));
    }
  }

  void playPlaylist(List<MusicTrack> tracks) {
    _queuePlaylists.clear();
    final qp = QueuePlaylist(name: '所有音频', tracks: tracks);
    _queuePlaylists.add(qp);
    _activePlaylistIndex = 0;
    _rebuildShuffleOrder();
    notifyListeners();
    if (tracks.isNotEmpty) {
      _loadAndPlayTrack(0);
    }
  }

  Future<void> addPlaylistToQueue(String name, List<MusicTrack> tracks) async {
    if (tracks.isEmpty) return;
    final qp = QueuePlaylist(name: name, tracks: tracks);
    _queuePlaylists.add(qp);
    _activePlaylistIndex = _queuePlaylists.length - 1;
    _rebuildShuffleOrder();
    notifyListeners();
    await _loadAndPlayTrack(0);
  }

  Future<void> switchToPlaylist(int newIndex) async {
    if (newIndex < 0 || newIndex >= _queuePlaylists.length) return;
    if (newIndex == _activePlaylistIndex) return;
    if (_activePlaylist != null) {
      _activePlaylist!.savedPosition = _position;
    }
    _activePlaylistIndex = newIndex;
    _rebuildShuffleOrder();
    final qp = _activePlaylist!;
    if (qp.currentTrackIndex >= 0 && qp.currentTrackIndex < qp.tracks.length) {
      await _loadAndPlayTrack(qp.currentTrackIndex);
      if (qp.savedPosition > Duration.zero) {
        seek(qp.savedPosition);
      }
    }
    notifyListeners();
  }

  void removePlaylistFromQueue(int index) {
    if (index < 0 || index >= _queuePlaylists.length) return;
    final wasActive = index == _activePlaylistIndex;
    _queuePlaylists.removeAt(index);
    if (_queuePlaylists.isEmpty) {
      stop();
      return;
    }
    if (wasActive) {
      _activePlaylistIndex = index.clamp(0, _queuePlaylists.length - 1);
      _rebuildShuffleOrder();
      if (_activePlaylist!.currentTrackIndex >= 0 &&
          _activePlaylist!.currentTrackIndex < _activePlaylist!.tracks.length) {
        _loadAndPlayTrack(_activePlaylist!.currentTrackIndex);
      }
    } else if (index < _activePlaylistIndex) {
      _activePlaylistIndex--;
    }
    notifyListeners();
  }

  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _loadAndPlayTrack(index);
  }

  void moveTrack(int from, int to) {
    if (_activePlaylist == null) return;
    final tracks = _activePlaylist!.tracks;
    if (from < 0 || from >= tracks.length || to < 0 || to >= tracks.length) return;
    final track = tracks.removeAt(from);
    tracks.insert(to, track);
    if (_currentIndex == from) {
      _currentIndex = to;
    } else if (from < _currentIndex && to >= _currentIndex) {
      _currentIndex--;
    } else if (from > _currentIndex && to <= _currentIndex) {
      _currentIndex++;
    }
    _rebuildShuffleOrder();
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (_activePlaylist == null) return;
    final tracks = _activePlaylist!.tracks;
    if (index < 0 || index >= tracks.length) return;
    tracks.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (tracks.isEmpty) {
        _currentIndex = -1;
        _cleanupCurrent();
      } else if (_currentIndex >= tracks.length) {
        _loadAndPlayTrack(0);
      } else {
        _loadAndPlayTrack(_currentIndex);
      }
      _rebuildShuffleOrder();
      notifyListeners();
      return;
    }
    _rebuildShuffleOrder();
    notifyListeners();
  }

  void addToQueue(MusicTrack track) {
    if (_activePlaylist == null) return;
    _activePlaylist!.tracks.add(track);
    _rebuildShuffleOrder();
    notifyListeners();
  }

  void insertNext(MusicTrack track) {
    if (_activePlaylist == null) return;
    final tracks = _activePlaylist!.tracks;
    final insertAt = (_currentIndex + 1).clamp(0, tracks.length);
    tracks.insert(insertAt, track);
    _rebuildShuffleOrder();
    notifyListeners();
  }

  void replaceTrackInQueue(String oldPath, MusicTrack newTrack) {
    bool changed = false;
    for (final qp in _queuePlaylists) {
      for (int i = 0; i < qp.tracks.length; i++) {
        if (qp.tracks[i].path == oldPath) {
          qp.tracks[i] = newTrack;
          changed = true;
        }
      }
    }
    if (changed) notifyListeners();
  }

  // ── Play mode ──

  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    if (mode == PlayMode.shuffle) {
      _rebuildShuffleOrder();
      _shufflePosition = _shuffleOrder.indexOf(_currentIndex);
    }
    notifyListeners();
  }

  void setInterruptMode(AudioInterruptMode mode) {
    _interruptMode = mode;
    notifyListeners();
    onInterruptModeChanged?.call(mode);
  }

  /// Callback invoked when the user changes interrupt mode (for persistence).
  void Function(AudioInterruptMode)? onInterruptModeChanged;

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
      return _playMode == PlayMode.repeatPlaylist ? 0 : -1;
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
    notifyListeners();

    final path = _queue[index].path;
    try {
      _currentSource = await SoLoud.instance.loadFile(path);
      _duration = SoLoud.instance.getLength(_currentSource!);
      _currentHandle = SoLoud.instance.play(_currentSource!, volume: _volume);
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioPlayer] Failed to load: $path, error: $e');
      final next = _nextIndex;
      if (next != -1 && next != index) {
        _loadAndPlayTrack(next);
      }
    }
  }

  void _onTrackComplete() {
    if (!_isPlaying) return; // guard against re-trigger
    _isPlaying = false;
    notifyListeners();
    final next = _nextIndex;
    if (next == -1) {
      if (_playMode == PlayMode.repeatAll) {
        if (_activePlaylistIndex < _queuePlaylists.length - 1) {
          switchToPlaylist(_activePlaylistIndex + 1);
        } else {
          switchToPlaylist(0);
        }
      }
      // sequential: stay on last track, paused
    } else {
      _loadAndPlayTrack(next);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _fadeTimer?.cancel();
    _cleanupCurrent();
    super.dispose();
  }
}
