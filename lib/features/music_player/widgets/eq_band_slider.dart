import 'package:flutter/material.dart';
import '../models/eq_preset.dart';

class EqBandSlider extends StatelessWidget {
  final int bandIndex;
  final double gain;
  final ValueChanged<double>? onChanged;

  const EqBandSlider({
    super.key,
    required this.bandIndex,
    required this.gain,
    this.onChanged,
  });

  double get frequency => EqPreset.bandFrequencies[bandIndex];
  String get label => EqPreset.formatFrequency(frequency);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onDoubleTap: () => onChanged?.call(0.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // dB value
          Text(
            '${gain.toStringAsFixed(1)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: gain.abs() < 0.5
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          // Vertical slider
          SizedBox(
            height: 160,
            child: RotatedBox(
              quarterTurns: -1,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: theme.colorScheme.primary,
                  inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Slider(
                  value: gain,
                  min: EqPreset.minGain,
                  max: EqPreset.maxGain,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Frequency label
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
