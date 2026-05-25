import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/eq_preset.dart';
import '../providers/playlist_provider.dart';
import '../services/equalizer_service.dart';
import '../widgets/eq_band_slider.dart';
import '../widgets/eq_preset_manager.dart';

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  final _eqService = EqualizerService.instance;
  late String? _activePresetName;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = _eqService.isEnabled;
    _activePresetName = _eqService.activePresetName ?? 'Flat';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistProvider>().loadEqPresets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = context.watch<PlaylistProvider>().eqPresets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('均衡器'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // On/Off toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('均衡器', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Switch(
                    value: _enabled,
                    onChanged: (v) {
                      setState(() => _enabled = v);
                      _eqService.setEnabled(v);
                    },
                  ),
                ],
              ),
            ),
            // Active preset name
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _activePresetName ?? 'Custom',
                key: ValueKey(_activePresetName),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Preset chips
            EqPresetManager(
              presets: presets,
              activePresetName: _activePresetName,
              onSelect: (preset) => _applyPreset(preset),
              onLongPress: (preset) => _showPresetMenu(context, preset),
              onSave: () => _showSaveDialog(context),
            ),
            const SizedBox(height: 16),
            // EQ band sliders
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(EqPreset.bandCount, (i) {
                    return Expanded(
                      child: EqBandSlider(
                        bandIndex: i,
                        gain: _eqService.gains[i],
                        onChanged: (v) {
                          setState(() {
                            _eqService.setBandGain(i, v);
                            _activePresetName = 'Custom';
                          });
                        },
                      ),
                    );
                  }),
                ),
              ),
            ),
            // EQ curve preview
            SizedBox(
              height: 80,
              child: CustomPaint(
                size: Size.infinite,
                painter: _EqCurvePainter(
                  gains: _eqService.gains,
                  enabled: _enabled,
                  color: theme.colorScheme.primary,
                  surfaceColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      _eqService.reset();
                      _activePresetName = 'Flat';
                      setState(() {});
                    },
                    child: const Text('重置'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showSaveDialog(context),
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('保存预设'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyPreset(EqPreset preset) {
    _eqService.applyPreset(preset);
    _activePresetName = preset.name;
    setState(() {});
  }

  void _showPresetMenu(BuildContext context, EqPreset preset) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, preset);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, preset);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, EqPreset preset) {
    final controller = TextEditingController(text: preset.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名预设'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && preset.id != null) {
                context.read<PlaylistProvider>().updateEqPreset(
                      preset.id!,
                      name,
                      _eqService.gains,
                    );
                _activePresetName = name;
                setState(() {});
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, EqPreset preset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除预设'),
        content: Text('确定删除 "${preset.name}"？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (preset.id != null) {
                context.read<PlaylistProvider>().deleteEqPreset(preset.id!);
              }
              if (_activePresetName == preset.name) {
                _activePresetName = 'Flat';
                _eqService.reset();
                setState(() {});
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showSaveDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存预设'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '预设名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<PlaylistProvider>().saveEqPreset(
                      name,
                      List.from(_eqService.gains),
                    );
                _activePresetName = name;
                setState(() {});
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _EqCurvePainter extends CustomPainter {
  final List<double> gains;
  final bool enabled;
  final Color color;
  final Color surfaceColor;

  _EqCurvePainter({
    required this.gains,
    required this.enabled,
    required this.color,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled || gains.isEmpty) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final midY = size.height / 2;
    final stepX = size.width / (gains.length - 1);
    final scaleY = midY / 12.0;

    final path = Path();
    for (int i = 0; i < gains.length; i++) {
      final x = i * stepX;
      final y = midY - gains[i] * scaleY;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter oldDelegate) =>
      gains != oldDelegate.gains || enabled != oldDelegate.enabled;
}
