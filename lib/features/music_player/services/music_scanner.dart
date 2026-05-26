import 'dart:io';
import '../models/music_track.dart';
import '../../../core/file_item.dart';

class MusicScanner {
  static const audioExtensions = {
    'mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'wma', 'opus', 'aiff',
  };

  Future<List<MusicTrack>> scanDirectory(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) return [];

    final tracks = <MusicTrack>[];

    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final ext = entity.uri.pathSegments.last.split('.').last.toLowerCase();
          if (audioExtensions.contains(ext)) {
            tracks.add(MusicTrack.fromFileItem(
              FileItem.fromFileSystem(entity),
            ));
          }
        }
      }
    } catch (_) {
      // Permission denied or other IO error — return what we have
    }

    tracks.sort((a, b) => a.title.compareTo(b.title));
    return tracks;
  }

  Future<List<MusicTrack>> scanDefaultLocations() async {
    final musicDir = _defaultMusicPath();
    if (musicDir != null) {
      return scanDirectory(musicDir);
    }
    return [];
  }

  String? _defaultMusicPath() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'];
    if (home == null) return null;
    return '$home${Platform.pathSeparator}Music';
  }
}
