import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import '../services/audio_player_service.dart';
import '../models/music_track.dart';


import '../widgets/track_list_tile.dart';
import '../widgets/add_to_playlist_sheet.dart';

class PlaylistDetailPage extends StatefulWidget {
  final int initialIndex;

  const PlaylistDetailPage({super.key, this.initialIndex = 0});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<PlaylistProvider>(
        builder: (context, provider, _) {
          final playlists = provider.playlists;

          if (playlists.isEmpty) {
            return const Center(child: Text('暂无歌单'));
          }

          final clampedIndex = _currentPage.clamp(0, playlists.length - 1);
          final currentPlaylist = playlists[clampedIndex];

          return SafeArea(
            child: Column(
              children: [
                // Header with animated playlist name
                _buildHeader(context, currentPlaylist, playlists),
                // Track list with PageView
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: playlists.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return _buildTrackList(context, playlist);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, Playlist playlist, List<Playlist> allPlaylists) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: '添加曲目',
                onPressed: () => _showAddTracks(context, playlist),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                playlist.name,
                key: ValueKey(playlist.id),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${playlist.trackCount} 首',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: playlist.trackPaths.isEmpty
                      ? null
                      : () {
                          final tracks = playlist.trackPaths
                              .map((p) => MusicTrack.fromPath(p))
                              .toList();
                          if (tracks.isNotEmpty) {
                            context.read<AudioPlayerService>().playQueue(tracks, startIndex: 0);
                          }
                        },
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('播放全部'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: playlist.trackPaths.isEmpty
                      ? null
                      : () {
                          final tracks = playlist.trackPaths
                              .map((p) => MusicTrack.fromPath(p))
                              .toList();
                          tracks.shuffle();
                          if (tracks.isNotEmpty) {
                            context.read<AudioPlayerService>().playQueue(tracks, startIndex: 0);
                          }
                        },
                  icon: const Icon(Icons.shuffle, size: 20),
                  label: const Text('随机播放'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: playlist.trackPaths.isEmpty
                      ? null
                      : () {
                          final tracks = playlist.trackPaths
                              .map((p) => MusicTrack.fromPath(p))
                              .toList();
                          if (tracks.isNotEmpty) {
                            final player = context.read<AudioPlayerService>();
                            player.addPlaylistToQueue(playlist.name, tracks);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已加入队列: ${playlist.name}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.queue_play_next, size: 20),
                  label: const Text('加入队列'),
                ),
              ],
            ),
          ),
          // Page indicator
          if (allPlaylists.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  allPlaylists.length,
                  (i) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _currentPage
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackList(BuildContext context, Playlist playlist) {
    if (playlist.trackPaths.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('歌单为空'),
            const SizedBox(height: 4),
            Text('点击右上角 + 添加曲目',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    final tracks = playlist.trackPaths
        .map((p) => MusicTrack.fromPath(p))
        .toList();

    return ReorderableListView.builder(
      itemCount: tracks.length,
      onReorder: (oldIndex, newIndex) {
        final pl = context.read<PlaylistProvider>().playlists[_currentPage];
        if (pl.id != null) {
          context.read<PlaylistProvider>().reorderPlaylist(
                pl.id!,
                oldIndex,
                newIndex,
              );
        }
      },
      buildDefaultDragHandles: true,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final player = context.watch<AudioPlayerService>();
        final isPlaying = player.currentTrack == track && player.isPlaying;

        return Dismissible(
          key: ValueKey('${playlist.id}_${track.path}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Icon(Icons.delete,
                color: Theme.of(context).colorScheme.error),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('移除曲目'),
                content: Text('从歌单中移除 "${track.title}"？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('移除'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) {
            if (playlist.id != null) {
              context.read<PlaylistProvider>().removeFromPlaylist(
                    playlist.id!,
                    track.path,
                  );
            }
          },
          child: TrackListTile(
            track: track,
            isPlaying: isPlaying,
            onTap: () {
              context.read<AudioPlayerService>().playQueue(tracks, startIndex: index);
            },
          ),
        );
      },
    );
  }

  void _showAddTracks(BuildContext context, Playlist playlist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddToPlaylistSheet(playlistId: playlist.id!),
    );
  }
}
