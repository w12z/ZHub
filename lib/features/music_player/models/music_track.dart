import 'dart:io';
import '../../../core/file_item.dart';

class MusicTrack {
  final String path;
  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final int fileSize;

  const MusicTrack({
    required this.path,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    required this.fileSize,
  });

  factory MusicTrack.fromFileItem(FileItem item) {
    final nameWithoutExt = item.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    return MusicTrack(
      path: item.path,
      title: nameWithoutExt,
      fileSize: item.size,
    );
  }

  factory MusicTrack.fromPath(String path) {
    final file = File(path);
    final stat = file.statSync();
    final name = FileItem.nameFromPath(path);
    final nameWithoutExt = name.replaceAll(RegExp(r'\.[^.]+$'), '');
    return MusicTrack(
      path: path,
      title: nameWithoutExt,
      fileSize: stat.size,
    );
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDuration {
    if (duration == null) return '--:--';
    final m = duration!.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration!.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration!.inHours > 0 ? '${duration!.inHours}:' : ''}$m:$s';
  }

  String get subtitle => artist ?? album ?? formattedSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MusicTrack && path == other.path;

  @override
  int get hashCode => path.hashCode;
}
