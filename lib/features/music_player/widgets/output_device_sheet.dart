import 'package:flutter/material.dart';
import '../services/audio_routing_service.dart';

class OutputDeviceSheet extends StatefulWidget {
  const OutputDeviceSheet({super.key});

  @override
  State<OutputDeviceSheet> createState() => _OutputDeviceSheetState();
}

class _OutputDeviceSheetState extends State<OutputDeviceSheet> {
  final _routingService = DefaultAudioRoutingService();
  List<AudioDevice> _devices = [];
  String? _activeDeviceId = 'default';

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final devices = await _routingService.getDevices();
    final active = devices.where((d) => d.isActive).firstOrNull;
    setState(() {
      _devices = devices;
      _activeDeviceId = active?.id ?? 'default';
    });
  }

  IconData _iconForType(AudioDeviceType type) {
    return switch (type) {
      AudioDeviceType.bluetooth => Icons.bluetooth,
      AudioDeviceType.speaker => Icons.speaker,
      AudioDeviceType.wired => Icons.headphones,
      AudioDeviceType.airplay => Icons.airplay,
      AudioDeviceType.other => Icons.devices,
    };
  }

  String _labelForType(AudioDeviceType type) {
    return switch (type) {
      AudioDeviceType.bluetooth => '蓝牙',
      AudioDeviceType.speaker => '扬声器',
      AudioDeviceType.wired => '有线耳机',
      AudioDeviceType.airplay => 'AirPlay',
      AudioDeviceType.other => '其他',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
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
          child: Text('输出设备',
              style: theme.textTheme.titleMedium),
        ),
        if (_devices.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('未检测到设备'),
          )
        else
          ..._devices.map((device) {
            final isActive = device.id == _activeDeviceId;
            return ListTile(
              leading: Icon(
                _iconForType(device.type),
                color: isActive ? theme.colorScheme.primary : null,
              ),
              title: Text(device.name),
              subtitle: Text(_labelForType(device.type)),
              trailing: isActive
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              onTap: () {
                _routingService.switchToDevice(device.id);
                setState(() => _activeDeviceId = device.id);
                Navigator.pop(context);
              },
            );
          }),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('打开系统声音设置'),
          onTap: () {
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
