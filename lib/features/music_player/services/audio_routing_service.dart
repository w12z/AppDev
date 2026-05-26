import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'music_player_settings.dart';

class AudioDevice {
  final int id;
  final String name;
  final bool isActive;

  const AudioDevice({
    required this.id,
    required this.name,
    this.isActive = false,
  });
}

class AudioRoutingService {
  static final AudioRoutingService instance = AudioRoutingService._();
  AudioRoutingService._();

  MusicPlayerSettings? _playerSettings;
  final _deviceChangedController = StreamController<AudioDevice?>.broadcast();
  int? _activeDeviceId;

  Stream<AudioDevice?> get onDeviceChanged => _deviceChangedController.stream;

  void attachSettings(MusicPlayerSettings settings) {
    _playerSettings = settings;
  }

  Future<void> loadFromSettings() async {
    if (_playerSettings == null) return;
    _activeDeviceId = _playerSettings!.outputDeviceId;
  }

  void startMonitoring(int deviceId) {
    _activeDeviceId = deviceId;
  }

  List<AudioDevice> listDevices() {
    final playbackDevices = SoLoud.instance.listPlaybackDevices();
    // Initialize active device from system default on first call
    if (_activeDeviceId == null) {
      final defaultDevice = playbackDevices.firstWhere(
        (d) => d.isDefault,
        orElse: () => playbackDevices.first,
      );
      _activeDeviceId = defaultDevice.id;
    }
    return playbackDevices.map((d) {
      return AudioDevice(
        id: d.id,
        name: d.name,
        isActive: d.id == _activeDeviceId,
      );
    }).toList();
  }

  Future<void> switchToDevice(int deviceId) async {
    final devices = SoLoud.instance.listPlaybackDevices();
    final target = devices.cast<PlaybackDevice?>().firstWhere(
      (d) => d?.id == deviceId,
      orElse: () => null,
    );
    if (target != null) {
      _activeDeviceId = deviceId;
      SoLoud.instance.changeDevice(newDevice: target);
      _playerSettings?.saveOutputDevice(deviceId);
      debugPrint('[AudioRouting] Switched to: ${target.name} (id: $deviceId)');
    }
  }

  int? get activeDeviceId => _activeDeviceId;

  void dispose() {
    _deviceChangedController.close();
  }
}
