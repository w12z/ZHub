import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';

class PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final PlayMode playMode;
  final VoidCallback? onPrevious;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onToggleMode;

  const PlaybackControls({
    super.key,
    required this.isPlaying,
    required this.playMode,
    this.onPrevious,
    this.onPlayPause,
    this.onNext,
    this.onToggleMode,
  });

  String get _modeLabel {
    return switch (playMode) {
      PlayMode.sequential => '顺序',
      PlayMode.shuffle => '随机',
      PlayMode.repeatOne => '单曲',
      PlayMode.repeatAll => '循环',
    };
  }

  IconData get _modeIcon {
    return switch (playMode) {
      PlayMode.sequential => Icons.repeat,
      PlayMode.shuffle => Icons.shuffle,
      PlayMode.repeatOne => Icons.repeat_one,
      PlayMode.repeatAll => Icons.repeat,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(_modeIcon, size: 24),
          color: playMode == PlayMode.sequential
              ? theme.colorScheme.onSurface
              : theme.colorScheme.primary,
          onPressed: onToggleMode,
          tooltip: _modeLabel,
        ),
        const SizedBox(width: 16),
        IconButton.filled(
          icon: const Icon(Icons.skip_previous, size: 28),
          onPressed: onPrevious,
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          icon: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            size: 36,
          ),
          onPressed: onPlayPause,
          style: IconButton.styleFrom(
            minimumSize: const Size(64, 64),
            shape: const CircleBorder(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          icon: const Icon(Icons.skip_next, size: 28),
          onPressed: onNext,
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 48,
          child: Text(
            _modeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: playMode == PlayMode.sequential
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
