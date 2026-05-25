import 'package:flutter/foundation.dart';
import '../models/eq_preset.dart';

class EqualizerService {
  bool _enabled = false;
  final List<double> _gains = List.filled(EqPreset.bandCount, 0.0);

  bool get isEnabled => _enabled;
  List<double> get gains => List.unmodifiable(_gains);

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    // Platform channel call for native EQ toggle
    debugPrint('[EQ] setEnabled: $enabled');
  }

  Future<void> setBandGain(int band, double gainDb) async {
    if (band < 0 || band >= EqPreset.bandCount) return;
    _gains[band] = gainDb.clamp(EqPreset.minGain, EqPreset.maxGain);
    // Platform channel call for per-band gain
    debugPrint('[EQ] setBandGain: band=$band, gain=${_gains[band].toStringAsFixed(1)}dB');
  }

  Future<void> applyGains(List<double> gains) async {
    for (int i = 0; i < gains.length && i < EqPreset.bandCount; i++) {
      _gains[i] = gains[i].clamp(EqPreset.minGain, EqPreset.maxGain);
    }
    // Platform channel call to apply all gains
    debugPrint('[EQ] applyGains: $_gains');
  }

  Future<void> applyPreset(EqPreset preset) async {
    await applyGains(preset.gains);
    debugPrint('[EQ] applyPreset: ${preset.name}');
  }

  Future<void> reset() async {
    for (int i = 0; i < EqPreset.bandCount; i++) {
      _gains[i] = 0.0;
    }
    debugPrint('[EQ] reset: all bands to 0dB');
  }

  void dispose() {}
}
