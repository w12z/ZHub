import 'package:flutter/foundation.dart';
import '../models/music_track.dart';
import '../services/music_scanner.dart';

class MusicLibraryProvider extends ChangeNotifier {
  final MusicScanner _scanner = MusicScanner();

  List<MusicTrack> _allTracks = [];
  final List<MusicTrack> _recentlyPlayed = [];
  bool _isLoading = false;
  String? _error;

  List<MusicTrack> get allTracks => _allTracks;
  List<MusicTrack> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> scanDefaultLocations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allTracks = await _scanner.scanDefaultLocations();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> scanDirectory(String path) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allTracks = await _scanner.scanDirectory(path);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

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
