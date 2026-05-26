import 'dart:async';
import 'package:flutter/services.dart';

/// Cross-platform audio session monitor.
/// Polling is handled by AudioPlayerService; this is a thin MethodChannel wrapper.
class AudioSessionMonitor {
  static final AudioSessionMonitor instance = AudioSessionMonitor._();
  AudioSessionMonitor._();

  static const _channel = MethodChannel('com.filehub/audio_focus');

  bool _started = false;

  void start() {
    _started = true;
  }

  Future<bool> hasOtherAudio() async {
    if (!_started) return false;
    try {
      return await _channel.invokeMethod<bool>('hasOtherAudio') ?? false;
    } catch (_) {
      return false;
    }
  }

  void stop() {
    _started = false;
  }
}
