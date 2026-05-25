import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/music_track.dart';
import '../models/playlist.dart';
import '../services/audio_player_service.dart';

class PlayerStateProvider extends ChangeNotifier {
  static AudioInterruptMode? _savedInterruptMode;
  static void Function(AudioInterruptMode)? onInterruptModeChanged;

  static void setDefaultInterruptMode(AudioInterruptMode mode) {
    _savedInterruptMode = mode;
  }

  final AudioPlayerService _audioService = AudioPlayerService();
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _indexSub;
  StreamSubscription? _volumeSub;
  StreamSubscription? _modeSub;
  StreamSubscription? _interruptSub;
  StreamSubscription? _queueSub;

  // ── Reactive state ──

  bool _isPlaying = false;
  MusicTrack? _currentTrack;
  List<MusicTrack> _queue = [];
  int? _currentIndex;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  PlayMode _playMode = PlayMode.sequential;
  AudioInterruptMode _interruptMode = AudioInterruptMode.pause;

  bool get isPlaying => _isPlaying;
  MusicTrack? get currentTrack => _currentTrack;
  List<MusicTrack> get queue => _queue;
  int? get currentIndex => _currentIndex;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  PlayMode get playMode => _playMode;
  AudioInterruptMode get interruptMode => _interruptMode;

  double get positionFraction =>
      _duration.inMilliseconds > 0
          ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

  PlayerStateProvider() {
    if (_savedInterruptMode != null) {
      _interruptMode = _savedInterruptMode!;
      _audioService.setInterruptMode(_savedInterruptMode!);
    }
    _stateSub = _audioService.playbackState.listen((state) {
      _isPlaying = state == PlaybackState.playing;
      notifyListeners();
    });

    _indexSub = _audioService.currentIndex.listen((idx) {
      _currentIndex = idx;
      _currentTrack = idx != null ? _audioService.currentTrack : null;
      notifyListeners();
    });

    _positionSub = _audioService.position.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _durationSub = _audioService.duration.listen((dur) {
      _duration = dur;
      notifyListeners();
    });

    _volumeSub = _audioService.volume.listen((vol) {
      _volume = vol;
      notifyListeners();
    });

    _modeSub = _audioService.playMode.listen((mode) {
      _playMode = mode;
      notifyListeners();
    });

    _interruptSub = _audioService.interruptModeStream.listen((mode) {
      _interruptMode = mode;
      notifyListeners();
    });

    _queueSub = _audioService.queue.listen((q) {
      _queue = q;
      notifyListeners();
    });
  }

  // ── Actions ──

  void playQueue(List<MusicTrack> tracks, int startIndex) {
    _audioService.loadQueue(tracks, startIndex: startIndex);
  }

  void playPlaylist(Playlist playlist) {
    final tracks = playlist.trackPaths.map((p) => MusicTrack.fromPath(p)).toList();
    _audioService.loadQueue(tracks);
  }

  void togglePlayPause() {
    if (_isPlaying) {
      _audioService.pause();
    } else {
      _audioService.play();
    }
  }

  void next() => _audioService.skipToNext();
  void previous() => _audioService.skipToPrevious();
  void seek(Duration pos) => _audioService.seek(pos);
  void setVolume(double v) => _audioService.setVolume(v);
  void setPlayMode(PlayMode mode) => _audioService.setPlayMode(mode);
  void setInterruptMode(AudioInterruptMode mode) {
    _interruptMode = mode;
    _audioService.setInterruptMode(mode);
    onInterruptModeChanged?.call(mode);
    notifyListeners();
  }
  void moveInQueue(int from, int to) => _audioService.moveTrack(from, to);
  void removeFromQueue(int index) => _audioService.removeFromQueue(index);
  void addToQueue(MusicTrack track) => _audioService.addToQueue(track);
  void insertNext(MusicTrack track) => _audioService.insertNext(track);

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _indexSub?.cancel();
    _volumeSub?.cancel();
    _modeSub?.cancel();
    _interruptSub?.cancel();
    _queueSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
