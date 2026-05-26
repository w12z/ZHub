class Playlist {
  final int? id;
  final String name;
  final List<String> trackPaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    this.id,
    required this.name,
    required this.trackPaths,
    required this.createdAt,
    required this.updatedAt,
  });

  int get trackCount => trackPaths.length;

  Playlist copyWith({
    int? id,
    String? name,
    List<String>? trackPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      trackPaths: trackPaths ?? this.trackPaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Playlist withReorderedTracks(int oldIndex, int newIndex) {
    final tracks = List<String>.from(trackPaths);
    final item = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, item);
    return copyWith(trackPaths: tracks, updatedAt: DateTime.now());
  }

  Playlist withAddedTrack(String path) {
    if (trackPaths.contains(path)) return this;
    return copyWith(
      trackPaths: [...trackPaths, path],
      updatedAt: DateTime.now(),
    );
  }

  Playlist withRemovedTrack(String path) {
    return copyWith(
      trackPaths: trackPaths.where((p) => p != path).toList(),
      updatedAt: DateTime.now(),
    );
  }
}
