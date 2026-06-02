import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/eq_preset.dart';
import '../providers/music_library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/audio_player_service.dart';
import '../services/audio_routing_service.dart';
import '../services/equalizer_service.dart';
import '../widgets/eq_band_slider.dart';
import '../widgets/eq_preset_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _eqService = EqualizerService.instance;
  final _routingService = AudioRoutingService.instance;
  late bool _eqEnabled;
  late String? _activePresetName;
  List<AudioDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _eqEnabled = _eqService.isEnabled;
    _activePresetName = _eqService.activePresetName ?? 'Flat';
    _loadDevices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistProvider>().loadEqPresets();
    });
  }

  void _loadDevices() {
    setState(() => _devices = _routingService.listDevices());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<AudioPlayerService>();
    final presets = context.watch<PlaylistProvider>().eqPresets;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildMusicFolderSection(theme),
          const Divider(height: 32),
          _buildPlayModeSection(player, theme),
          const Divider(height: 32),
          _buildEqSection(presets, theme),
          const Divider(height: 32),
          _buildOutputDeviceSection(theme),
          const Divider(height: 32),
          _buildInterruptSection(player, theme),
        ],
      ),
    );
  }

  // ── Music Folder ──

  Widget _buildMusicFolderSection(ThemeData theme) {
    final musicPath = context.watch<MusicLibraryProvider>().musicFolderPath;
    return _SectionCard(
      title: '音乐文件夹',
      child: ListTile(
        leading: Icon(Icons.folder_open, color: theme.colorScheme.primary),
        title: Text(musicPath ?? '未设置'),
        subtitle: const Text('Wi-Fi 传输可直接保存音乐到此文件夹'),
        trailing: const Icon(Icons.edit_location_alt),
        onTap: () async {
          final path = await FilePicker.platform.getDirectoryPath();
          if (path != null && context.mounted) {
            context.read<MusicLibraryProvider>().setMusicFolderPath(path);
          }
        },
      ),
    );
  }

  // ── Play Mode ──

  Widget _buildPlayModeSection(AudioPlayerService player, ThemeData theme) {
    const modes = PlayMode.values;
    return _SectionCard(
      title: '播放模式',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: modes.map((mode) {
          final selected = player.playMode == mode;
          return ChoiceChip(
            label: Text(_playModeLabel(mode)),
            selected: selected,
            onSelected: (_) => player.setPlayMode(mode),
            selectedColor: theme.colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: selected ? theme.colorScheme.primary : null,
              fontWeight: selected ? FontWeight.bold : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _playModeLabel(PlayMode mode) {
    return switch (mode) {
      PlayMode.sequential => '顺序',
      PlayMode.shuffle => '随机',
      PlayMode.repeatOne => '单曲循环',
      PlayMode.repeatPlaylist => '歌单循环',
      PlayMode.repeatAll => '全部循环',
    };
  }

  // ── Equalizer ──

  Widget _buildEqSection(List<EqPreset> presets, ThemeData theme) {
    return _SectionCard(
      title: '均衡器',
      trailing: Switch(
        value: _eqEnabled,
        onChanged: (v) {
          setState(() => _eqEnabled = v);
          _eqService.setEnabled(v);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          EqPresetManager(
            presets: presets,
            activePresetName: _activePresetName,
            onSelect: (preset) => _applyPreset(preset),
            onLongPress: (preset) => _showPresetMenu(preset),
            onSave: () => _showSaveDialog(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
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
          const SizedBox(height: 4),
          SizedBox(
            height: 60,
            child: CustomPaint(
              size: Size.infinite,
              painter: _EqCurvePainter(
                gains: _eqService.gains,
                enabled: _eqEnabled,
                color: theme.colorScheme.primary,
                surfaceColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
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
                  onPressed: () => _showSaveDialog(),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('保存预设'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyPreset(EqPreset preset) {
    _eqService.applyPreset(preset);
    _activePresetName = preset.name;
    setState(() {});
  }

  void _showPresetMenu(EqPreset preset) {
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
                _showRenameDialog(preset);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(preset);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(EqPreset preset) {
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && preset.id != null) {
                context.read<PlaylistProvider>().updateEqPreset(
                      preset.id!, name, _eqService.gains,
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

  void _confirmDelete(EqPreset preset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除预设'),
        content: Text('确定删除 "${preset.name}"？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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

  void _showSaveDialog() {
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<PlaylistProvider>().saveEqPreset(
                      name, List.from(_eqService.gains),
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

  // ── Output Device ──

  Widget _buildOutputDeviceSection(ThemeData theme) {
    return _SectionCard(
      title: '输出设备',
      trailing: OutlinedButton.icon(
        onPressed: _loadDevices,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('刷新', style: TextStyle(fontSize: 13)),
      ),
      child: _devices.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('未检测到设备', style: TextStyle(color: Colors.grey)),
            )
          : Column(
              children: _devices.map((device) {
                return ListTile(
                  leading: Icon(
                    _iconForDevice(device.name),
                    color: device.isActive ? theme.colorScheme.primary : null,
                  ),
                  title: Text(device.name),
                  trailing: device.isActive
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () async {
                    await _routingService.switchToDevice(device.id);
                    _loadDevices();
                  },
                );
              }).toList(),
            ),
    );
  }

  IconData _iconForDevice(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('bluetooth')) return Icons.bluetooth;
    if (lower.contains('headphone') || lower.contains('headset') || lower.contains('耳机')) {
      return Icons.headphones;
    }
    return Icons.speaker;
  }

  // ── Interrupt Mode ──

  Widget _buildInterruptSection(AudioPlayerService player, ThemeData theme) {
    return _SectionCard(
      title: '音频打断策略',
      child: Column(
        children: [
          RadioListTile<AudioInterruptMode>(
            title: const Text('暂停播放'),
            subtitle: const Text('其他应用发声时暂停'),
            value: AudioInterruptMode.pause,
            groupValue: player.interruptMode,
            onChanged: (v) {
              if (v != null) player.setInterruptMode(v);
            },
          ),
          RadioListTile<AudioInterruptMode>(
            title: const Text('不中断但降低音量'),
            subtitle: const Text('降低至 20% 音量继续播放'),
            value: AudioInterruptMode.duck,
            groupValue: player.interruptMode,
            onChanged: (v) {
              if (v != null) player.setInterruptMode(v);
            },
          ),
        ],
      ),
    );
  }
}

// ── Section card wrapper ──

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── EQ curve painter (moved from equalizer_page.dart) ──

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
