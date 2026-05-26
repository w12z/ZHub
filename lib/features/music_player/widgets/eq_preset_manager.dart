import 'package:flutter/material.dart';
import '../models/eq_preset.dart';

class EqPresetManager extends StatelessWidget {
  final List<EqPreset> presets;
  final String? activePresetName;
  final void Function(EqPreset preset)? onSelect;
  final void Function(EqPreset preset)? onLongPress;
  final VoidCallback? onSave;

  const EqPresetManager({
    super.key,
    required this.presets,
    this.activePresetName,
    this.onSelect,
    this.onLongPress,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: presets.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // Save button at the end
          if (index == presets.length) {
            return ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('保存'),
              onPressed: onSave,
            );
          }

          final preset = presets[index];
          final isActive = preset.name == activePresetName;

          final chip = InputChip(
            selected: isActive,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  preset.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : null,
                  ),
                ),
                if (preset.isBuiltIn) ...[
                  const SizedBox(width: 4),
                  Text('内置',
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
                ],
              ],
            ),
            onPressed: () => onSelect?.call(preset),
          );

          if (preset.isBuiltIn) return chip;
          return GestureDetector(
            onLongPress: () => onLongPress?.call(preset),
            child: chip,
          );
        },
      ),
    );
  }
}
