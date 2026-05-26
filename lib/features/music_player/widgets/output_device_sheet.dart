import 'package:flutter/material.dart';
import '../services/audio_routing_service.dart';

class OutputDeviceSheet extends StatefulWidget {
  const OutputDeviceSheet({super.key});

  @override
  State<OutputDeviceSheet> createState() => _OutputDeviceSheetState();
}

class _OutputDeviceSheetState extends State<OutputDeviceSheet> {
  final _routingService = AudioRoutingService.instance;
  List<AudioDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() {
    setState(() {
      _devices = _routingService.listDevices();
    });
  }

  IconData _iconForDevice(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('bluetooth')) return Icons.bluetooth;
    if (lower.contains('headphone') || lower.contains('headset') || lower.contains('耳机')) {
      return Icons.headphones;
    }
    return Icons.speaker;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('输出设备', style: theme.textTheme.titleMedium),
          ),
          if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('未检测到设备'),
            )
          else
            ..._devices.map((device) {
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
            }),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _loadDevices,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新设备列表'),
            ),
          ),
        ],
      ),
    );
  }
}
