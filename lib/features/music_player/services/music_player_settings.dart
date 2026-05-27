import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/eq_preset.dart';
import 'audio_player_service.dart';

class MusicPlayerSettings extends ChangeNotifier {
  Database? _db;

  void attach(Database db) => _db = db;

  Database get _ensureDb {
    if (_db == null) throw StateError('MusicPlayerSettings not attached to a database');
    return _db!;
  }

  bool eqEnabled = false;
  String eqActivePreset = 'Flat';
  List<double> eqGains = List.filled(EqPreset.bandCount, 0.0);
  int? outputDeviceId;
  AudioInterruptMode interruptMode = AudioInterruptMode.pause;

  // ── KV storage ──

  Future<void> _set(String key, String value) async {
    await _ensureDb.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Load / Save ──

  Future<void> load() async {
    final rows = await _ensureDb.query('settings');
    final map = {for (final r in rows) r['key'] as String: r['value'] as String};

    eqEnabled = map['eq_enabled'] == 'true';
    eqActivePreset = map['eq_active_preset'] ?? 'Flat';
    interruptMode = _parseInterruptMode(map['interrupt_mode']);
    outputDeviceId = map['output_device_id'] != null ? int.tryParse(map['output_device_id']!) : null;

    final gainsJson = map['eq_gains'];
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

  Future<void> saveEqState(bool enabled) async {
    eqEnabled = enabled;
    await _set('eq_enabled', enabled ? 'true' : 'false');
    notifyListeners();
  }

  Future<void> saveEqGains(List<double> gains) async {
    eqGains = List.from(gains);
    await _set('eq_gains', jsonEncode(eqGains));
    notifyListeners();
  }

  Future<void> saveEqPresetName(String name) async {
    eqActivePreset = name;
    await _set('eq_active_preset', name);
    notifyListeners();
  }

  Future<void> saveOutputDevice(int deviceId) async {
    outputDeviceId = deviceId;
    await _set('output_device_id', deviceId.toString());
  }

  Future<void> saveInterruptMode(AudioInterruptMode mode) async {
    interruptMode = mode;
    await _set('interrupt_mode', mode.name);
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
