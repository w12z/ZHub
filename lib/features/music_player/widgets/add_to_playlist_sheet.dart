import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_library_provider.dart';
import '../providers/playlist_provider.dart';

class AddToPlaylistSheet extends StatefulWidget {
  final int playlistId;

  const AddToPlaylistSheet({super.key, required this.playlistId});

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  final _selectedPaths = <String>{};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final library = context.watch<MusicLibraryProvider>();
    final tracks = library.allTracks;

    final filtered = _searchQuery.isEmpty
        ? tracks
        : tracks.where((t) {
            final q = _searchQuery.toLowerCase();
            return t.title.toLowerCase().contains(q) ||
                (t.artist?.toLowerCase().contains(q) ?? false);
          }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '添加曲目到歌单',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    '已选 ${_selectedPaths.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '搜索音乐...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const SizedBox(height: 8),
            // Action bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedPaths.clear());
                    },
                    child: const Text('清空选择'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _selectedPaths.isEmpty
                        ? null
                        : () {
                            final provider = context.read<PlaylistProvider>();
                            for (final path in _selectedPaths) {
                              provider.addToPlaylist(widget.playlistId, path);
                            }
                            Navigator.pop(context);
                          },
                    child: Text('添加 (${_selectedPaths.length})'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Track list
            Expanded(
              child: tracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('未扫描到音乐文件'),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () {
                              context.read<MusicLibraryProvider>().scanDefaultLocations();
                            },
                            child: const Text('扫描音乐'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final track = filtered[index];
                        final isSelected = _selectedPaths.contains(track.path);
                        return ListTile(
                          leading: Checkbox(
                            value: isSelected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedPaths.add(track.path);
                                } else {
                                  _selectedPaths.remove(track.path);
                                }
                              });
                            },
                          ),
                          title: Text(track.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(track.subtitle,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          selected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedPaths.remove(track.path);
                              } else {
                                _selectedPaths.add(track.path);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
