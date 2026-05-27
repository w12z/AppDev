import 'dart:io';
import '../models/music_track.dart';

class MusicScanner {
  static const audioExtensions = {
    'mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'wma', 'opus', 'aiff',
  };

  Future<List<MusicTrack>> scanDirectory(String path, {bool recursive = true}) async {
    final tracks = <MusicTrack>[];
    final dir = Directory(path);
    if (!await dir.exists()) return tracks;

    try {
      await for (final entity in dir.list(recursive: recursive)) {
        if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (audioExtensions.contains(ext)) {
            tracks.add(MusicTrack.fromPath(entity.path));
          }
        }
      }
    } catch (_) {}

    tracks.sort((a, b) => a.title.compareTo(b.title));
    return tracks;
  }
}
