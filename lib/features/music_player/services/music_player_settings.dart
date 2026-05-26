import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/eq_preset.dart';
import 'audio_player_service.dart';
import 'settings_repository.dart';

/// Centralized user settings for the music player module.
/// Eliminates scattered get/set calls across multiple services.
class MusicPlayerSettings extends ChangeNotifier {
  final SettingsRepository _repo;

  bool eqEnabled = false;
  String eqActivePreset = 'Flat';
  List<double> eqGains = List.filled(EqPreset.bandCount, 0.0);
  int? outputDeviceId;
  AudioInterruptMode interruptMode = AudioInterruptMode.pause;

  MusicPlayerSettings(this._repo);

  /// Load all settings from the repository in one pass.
  Future<void> load() async {
    eqEnabled = await _repo.getBool('eq_enabled');
    eqActivePreset = await _repo.get('eq_active_preset') ?? 'Flat';
    interruptMode = _parseInterruptMode(await _repo.get('interrupt_mode'));
    outputDeviceId = await _repo.getInt('output_device_id');

    final gainsJson = await _repo.get('eq_gains');
    if (gainsJson != null) {
      try {
        final list = (jsonDecode(gainsJson) as List)
            .map((e) => (e as num).toDouble())
            .toList();
        for (int i = 0; i < list.length && i < EqPreset.bandCount; i++) {
          eqGains[i] = list[i].clamp(EqPreset.minGain, EqPreset.maxGain);
        }
      } catch (_) {
        debugPrint('[MusicPlayerSettings] Failed to parse eq_gains');
      }
    }
    notifyListeners();
  }

  /// Persist mutable values. Only call for the key that changed.
  Future<void> saveEqState(bool enabled) async {
    eqEnabled = enabled;
    await _repo.setBool('eq_enabled', enabled);
    notifyListeners();
  }

  Future<void> saveEqGains(List<double> gains) async {
    eqGains = List.from(gains);
    await _repo.set('eq_gains', jsonEncode(eqGains));
    notifyListeners();
  }

  Future<void> saveEqPresetName(String name) async {
    eqActivePreset = name;
    await _repo.set('eq_active_preset', name);
    notifyListeners();
  }

  Future<void> saveOutputDevice(int deviceId) async {
    outputDeviceId = deviceId;
    await _repo.setInt('output_device_id', deviceId);
  }

  Future<void> saveInterruptMode(AudioInterruptMode mode) async {
    interruptMode = mode;
    await _repo.set('interrupt_mode', mode.name);
    notifyListeners();
  }

  static AudioInterruptMode _parseInterruptMode(String? raw) {
    if (raw == null) return AudioInterruptMode.pause;
    return AudioInterruptMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AudioInterruptMode.pause,
    );
  }
}
