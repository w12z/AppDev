import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

enum AudioDeviceType { bluetooth, speaker, wired, airplay, other }

class AudioDevice {
  final String id;
  final String name;
  final AudioDeviceType type;
  final bool isActive;

  const AudioDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = false,
  });
}

abstract class AudioRoutingService {
  Future<List<AudioDevice>> getDevices();
  Future<void> switchToDevice(String deviceId);
  Stream<AudioDevice?> get onDeviceChanged;
  AudioDevice? get currentDevice;
  Future<void> dispose();
}

class DefaultAudioRoutingService extends AudioRoutingService {
  final _deviceChangedController = StreamController<AudioDevice?>.broadcast();
  AudioDevice? _currentDevice = const AudioDevice(
    id: 'default',
    name: '默认输出',
    type: AudioDeviceType.speaker,
    isActive: true,
  );

  @override
  AudioDevice? get currentDevice => _currentDevice;

  @override
  Stream<AudioDevice?> get onDeviceChanged => _deviceChangedController.stream;

  @override
  Future<List<AudioDevice>> getDevices() async {
    final devices = <AudioDevice>[
      const AudioDevice(
        id: 'default',
        name: '默认输出',
        type: AudioDeviceType.speaker,
        isActive: true,
      ),
    ];

    if (Platform.isWindows) {
      devices.addAll(await _getWindowsDevices());
    }

    return devices;
  }

  Future<List<AudioDevice>> _getWindowsDevices() async {
    try {
      // Using win32audio to enumerate devices
      // For now, return a placeholder list
      return [
        const AudioDevice(
          id: 'speakers',
          name: '扬声器',
          type: AudioDeviceType.speaker,
        ),
        const AudioDevice(
          id: 'headphones',
          name: '耳机',
          type: AudioDeviceType.wired,
        ),
      ];
    } catch (e) {
      debugPrint('[AudioRouting] Windows device enumeration failed: $e');
      return [];
    }
  }

  @override
  Future<void> switchToDevice(String deviceId) async {
    debugPrint('[AudioRouting] switchToDevice: $deviceId');
    _currentDevice = AudioDevice(
      id: deviceId,
      name: deviceId,
      type: AudioDeviceType.speaker,
      isActive: true,
    );
    _deviceChangedController.add(_currentDevice);

    if (Platform.isWindows) {
      try {
        // Use win32audio to switch default device
      } catch (e) {
        debugPrint('[AudioRouting] Windows device switch failed: $e');
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _deviceChangedController.close();
  }
}
