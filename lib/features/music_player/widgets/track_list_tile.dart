import 'package:flutter/material.dart';
import '../models/music_track.dart';

class TrackListTile extends StatelessWidget {
  final MusicTrack track;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final Widget? trailing;

  const TrackListTile({
    super.key,
    required this.track,
    this.isPlaying = false,
    this.onTap,
    this.onMore,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: _LeadingIcon(isPlaying: isPlaying),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isPlaying ? theme.colorScheme.primary : null,
          fontWeight: isPlaying ? FontWeight.w600 : null,
        ),
      ),
      subtitle: Text(
        track.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing ??
          (onMore != null
              ? IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: onMore,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                )
              : Text(track.formattedDuration, style: theme.textTheme.bodySmall)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  final bool isPlaying;

  const _LeadingIcon({required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isPlaying
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note,
        color: isPlaying
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        size: 24,
      ),
    );
  }
}
