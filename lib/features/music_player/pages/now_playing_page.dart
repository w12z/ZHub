import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_state_provider.dart';
import '../services/audio_player_service.dart';
import 'equalizer_page.dart';
import '../widgets/output_device_sheet.dart';
import '../widgets/playback_controls.dart';
import '../widgets/progress_bar.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('正在播放'),
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<PlayerStateProvider>(
        builder: (context, player, _) {
          final track = player.currentTrack;
          if (track == null) {
            return const Center(child: Text('未选择曲目'));
          }

          return SafeArea(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                if (details.primaryVelocity! < -300) {
                  player.next();
                } else if (details.primaryVelocity! > 300) {
                  player.previous();
                }
              },
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Album art placeholder
                  Hero(
                    tag: 'album_art_${track.path}',
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.secondaryContainer,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.music_note,
                        size: 80,
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Track info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Text(
                          track.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          track.subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ProgressBar(
                      position: player.position,
                      duration: player.duration,
                      onSeek: (fraction) {
                        final seekTo = Duration(
                          milliseconds: (fraction * player.duration.inMilliseconds).round(),
                        );
                        player.seek(seekTo);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Playback controls
                  PlaybackControls(
                    isPlaying: player.isPlaying,
                    playMode: player.playMode,
                    onPrevious: player.previous,
                    onPlayPause: player.togglePlayPause,
                    onNext: player.next,
                    onToggleMode: () {
                      const modes = PlayMode.values;
                      final next = modes[(player.playMode.index + 1) % modes.length];
                      player.setPlayMode(next);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Volume slider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        Icon(
                          player.volume > 0.5 ? Icons.volume_up : Icons.volume_down,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        Expanded(
                          child: Slider(
                            value: player.volume,
                            onChanged: (v) => player.setVolume(v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Bottom action bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.queue_music),
                        tooltip: '队列',
                        onPressed: () => _showQueue(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.equalizer),
                        tooltip: '均衡器',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const EqualizerPage()),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.speaker),
                        tooltip: '输出设备',
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (_) => const OutputDeviceSheet(),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz),
                        tooltip: '更多设置',
                        onPressed: () => _showSettings(context),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showQueue(BuildContext context) {
    final player = context.read<PlayerStateProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) {
          final queue = player.queue;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '播放队列 (${queue.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: queue.length,
                  onReorderItem: (oldIndex, newIndex) {
                    player.moveInQueue(oldIndex, newIndex);
                  },
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    final isCurrent = index == player.currentIndex;
                    return ReorderableDragStartListener(
                      index: index,
                      key: ValueKey(track.path),
                      child: ListTile(
                        leading: Icon(
                          isCurrent ? Icons.play_arrow : Icons.drag_handle,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          track.title,
                          style: TextStyle(
                            color: isCurrent
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            fontWeight: isCurrent ? FontWeight.w600 : null,
                          ),
                        ),
                        subtitle: Text(track.subtitle),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            player.removeFromQueue(index);
                            Navigator.pop(ctx);
                          },
                        ),
                        onTap: () {
                          player.playQueue(queue, index);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSettings(BuildContext context) {
    final player = context.read<PlayerStateProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _InterruptModeSheet(player: player),
    );
  }
}

class _InterruptModeSheet extends StatefulWidget {
  final PlayerStateProvider player;
  const _InterruptModeSheet({required this.player});

  @override
  State<_InterruptModeSheet> createState() => _InterruptModeSheetState();
}

class _InterruptModeSheetState extends State<_InterruptModeSheet> {
  late AudioInterruptMode _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.player.interruptMode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('音频打断策略', style: theme.textTheme.titleMedium),
            ),
            RadioListTile<AudioInterruptMode>(
              title: const Text('暂停播放'),
              subtitle: const Text('其他应用发声时暂停'),
              value: AudioInterruptMode.pause,
              groupValue: _selected,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selected = v);
                  widget.player.setInterruptMode(v);
                }
              },
            ),
            RadioListTile<AudioInterruptMode>(
              title: const Text('不中断但降低音量'),
              subtitle: const Text('降低至 20% 音量继续播放'),
              value: AudioInterruptMode.duck,
              groupValue: _selected,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selected = v);
                  widget.player.setInterruptMode(v);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
