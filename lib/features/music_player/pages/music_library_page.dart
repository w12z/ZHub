import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_track.dart';
import '../providers/music_library_provider.dart';
import '../providers/player_state_provider.dart';
import '../widgets/track_list_tile.dart';

class MusicLibraryPage extends StatefulWidget {
  const MusicLibraryPage({super.key});

  @override
  State<MusicLibraryPage> createState() => _MusicLibraryPageState();
}

class _MusicLibraryPageState extends State<MusicLibraryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final library = context.read<MusicLibraryProvider>();
      if (library.allTracks.isEmpty && !library.isLoading) {
        library.scanDefaultLocations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<MusicLibraryProvider>().scanDefaultLocations();
            },
          ),
        ],
      ),
      body: Consumer<MusicLibraryProvider>(
        builder: (context, library, _) {
          if (library.isLoading && library.allTracks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (library.error != null && library.allTracks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(library.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => library.scanDefaultLocations(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          if (library.allTracks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    '未发现音乐文件',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请点击右上角扫描按钮',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => library.scanDefaultLocations(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('扫描音乐'),
                  ),
                ],
              ),
            );
          }

          final tracks = library.allTracks;
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              final player = context.watch<PlayerStateProvider>();
              final isPlaying = player.currentTrack == track && player.isPlaying;

              return TrackListTile(
                track: track,
                isPlaying: isPlaying,
                onTap: () {
                  context.read<PlayerStateProvider>().playQueue(tracks, index);
                  context.read<MusicLibraryProvider>().addToRecent(track);
                },
                onMore: () => _showTrackMenu(context, track),
              );
            },
          );
        },
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _MusicSearchDelegate(
        tracks: context.read<MusicLibraryProvider>().allTracks,
        onPlay: (track, all) {
          final tracks = all.cast<MusicTrack>().toList();
          final idx = tracks.indexOf(track as MusicTrack);
          context.read<PlayerStateProvider>().playQueue(tracks, idx);
        },
      ),
    );
  }

  void _showTrackMenu(BuildContext context, track) {
    final player = context.read<PlayerStateProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('下一首播放'),
              onTap: () {
                player.insertNext(track);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('添加到队列'),
              onTap: () {
                player.addToQueue(track);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('添加到歌单'),
              onTap: () {
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicSearchDelegate extends SearchDelegate<String> {
  final List<dynamic> tracks;
  final void Function(dynamic track, List<dynamic> all) onPlay;

  _MusicSearchDelegate({required this.tracks, required this.onPlay});

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.toLowerCase();
    final results = tracks.where((t) {
      return t.title.toLowerCase().contains(q) ||
          (t.artist?.toLowerCase().contains(q) ?? false) ||
          (t.album?.toLowerCase().contains(q) ?? false);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final track = results[index];
        return TrackListTile(
          track: track,
          onTap: () {
            onPlay(track, results);
            close(context, track.title);
          },
        );
      },
    );
  }
}
