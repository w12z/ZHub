import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_track.dart';
import '../services/music_scanner.dart';
import '../services/audio_player_service.dart';
import '../services/playlist_repository.dart';

class MusicLibraryProvider extends ChangeNotifier {
  final MusicScanner _scanner = MusicScanner();

  List<MusicTrack> _allTracks = [];
  final List<MusicTrack> _recentlyPlayed = [];
  bool _isLoading = false;
  String? _error;

  SharedPreferences? _prefs;
  String? _musicFolderPath;

  List<MusicTrack> get allTracks => _allTracks;
  List<MusicTrack> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get musicFolderPath => _musicFolderPath;

  Future<void> initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _musicFolderPath = _prefs!.getString('music_folder_path');
    notifyListeners();
  }

  void setMusicFolderPath(String path) {
    _musicFolderPath = path;
    _prefs?.setString('music_folder_path', path);
    notifyListeners();
  }

  // ── Cache ──

  Future<void> loadFromCache() async {
    final tracks = await PlaylistRepository.instance.getCachedTracks();
    if (tracks.isNotEmpty) {
      _allTracks = tracks;
      notifyListeners();
    }
  }

  // ── Scanning ──

  Future<void> scanDirectory(String path) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allTracks = await _scanner.scanDirectory(path);
      // Save to cache
      if (_allTracks.isNotEmpty) {
        await PlaylistRepository.instance.replaceCachedTracks(_allTracks);
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Rename ──

  Future<bool> renameTrack(MusicTrack track, String newName) async {
    try {
      final parent = Directory(track.path).parent.path;
      final newPath = '$parent${Platform.pathSeparator}$newName';
      await File(track.path).rename(newPath);

      final updated = track.copyWith(
        path: newPath,
        title: newName.replaceAll(RegExp(r'\.[^.]+$'), ''),
      );

      final repo = PlaylistRepository.instance;
      await repo.removeCachedTrack(track.path);
      await repo.upsertCachedTrack(updated);
      await repo.updateTrackPath(track.path, newPath);
      AudioPlayerService.instance.replaceTrackInQueue(track.path, updated);

      final idx = _allTracks.indexWhere((t) => t.path == track.path);
      if (idx != -1) _allTracks[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[MusicLibrary] Rename failed: $e');
      return false;
    }
  }

  // ── Recent / Search ──

  void addToRecent(MusicTrack track) {
    _recentlyPlayed.remove(track);
    _recentlyPlayed.insert(0, track);
    if (_recentlyPlayed.length > 50) {
      _recentlyPlayed.removeLast();
    }
    notifyListeners();
  }

  List<MusicTrack> search(String query) {
    final q = query.toLowerCase();
    return _allTracks.where((t) {
      return t.title.toLowerCase().contains(q) ||
          (t.artist?.toLowerCase().contains(q) ?? false) ||
          (t.album?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}
