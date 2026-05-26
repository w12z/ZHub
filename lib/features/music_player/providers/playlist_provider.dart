import 'package:flutter/foundation.dart';
import '../models/playlist.dart';
import '../models/eq_preset.dart';
import '../services/playlist_repository.dart';

class PlaylistProvider extends ChangeNotifier {
  final PlaylistRepository _repository = PlaylistRepository.instance;

  List<Playlist> _playlists = [];
  List<EqPreset> _eqPresets = [];
  bool _isLoading = false;

  List<Playlist> get playlists => _playlists;
  List<EqPreset> get eqPresets => _eqPresets;
  bool get isLoading => _isLoading;

  Future<void> loadPlaylists() async {
    _isLoading = true;
    notifyListeners();
    _playlists = await _repository.getAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<Playlist> createPlaylist(String name) async {
    final playlist = await _repository.create(name);
    _playlists.insert(0, playlist);
    notifyListeners();
    return playlist;
  }

  Future<void> deletePlaylist(int id) async {
    await _repository.delete(id);
    _playlists.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<void> renamePlaylist(int id, String newName) async {
    await _repository.rename(id, newName);
    final idx = _playlists.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _playlists[idx] = _playlists[idx].copyWith(name: newName);
      notifyListeners();
    }
  }

  Future<void> addToPlaylist(int playlistId, String trackPath) async {
    await _repository.addTrack(playlistId, trackPath);
    await _refreshPlaylist(playlistId);
  }

  Future<void> removeFromPlaylist(int playlistId, String trackPath) async {
    await _repository.removeTrack(playlistId, trackPath);
    await _refreshPlaylist(playlistId);
  }

  Future<void> reorderPlaylist(int playlistId, int oldIndex, int newIndex) async {
    await _repository.reorderTracks(playlistId, oldIndex, newIndex);
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      _playlists[idx] = _playlists[idx].withReorderedTracks(oldIndex, newIndex);
      notifyListeners();
    }
  }

  Future<void> _refreshPlaylist(int playlistId) async {
    final updated = await _repository.getById(playlistId);
    if (updated == null) return;
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      _playlists[idx] = updated;
      notifyListeners();
    }
  }

  // ── EQ Presets ──

  Future<void> loadEqPresets() async {
    _eqPresets = await _repository.getAllEqPresets();
    notifyListeners();
  }

  Future<EqPreset?> saveEqPreset(String name, List<double> gains) async {
    final id = await _repository.saveEqPreset(name, gains);
    await loadEqPresets();
    return _eqPresets.firstWhere((p) => p.id == id);
  }

  Future<void> updateEqPreset(int id, String name, List<double> gains) async {
    await _repository.updateEqPreset(id, name, gains);
    await loadEqPresets();
  }

  Future<void> deleteEqPreset(int id) async {
    await _repository.deleteEqPreset(id);
    _eqPresets.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }
}
