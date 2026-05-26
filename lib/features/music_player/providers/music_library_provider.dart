import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/music_track.dart';
import '../services/music_scanner.dart';
import '../services/audio_player_service.dart';
import '../services/playlist_repository.dart';

class MusicLibraryProvider extends ChangeNotifier {
  final MusicScanner _scanner = MusicScanner();

  List<MusicTrack> _allTracks = [];
  final List<MusicTrack> _recentlyPlayed = [];
  bool _isLoading = false;
  String? _error;
  ScanProgress _scanProgress = const ScanProgress(isComplete: true);

  List<MusicTrack> get allTracks => _allTracks;
  List<MusicTrack> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);
  bool get isLoading => _isLoading;
  String? get error => _error;
  ScanProgress get scanProgress => _scanProgress;

  // ── Cache ──

  Future<void> loadFromCache() async {
    final tracks = await PlaylistRepository.instance.getCachedTracks();
    if (tracks.isNotEmpty) {
      _allTracks = tracks;
      notifyListeners();
    }
  }

  // ── Scanning ──

  Future<void> startFullDiskScan() async {
    _isLoading = true;
    _error = null;
    _scanProgress = const ScanProgress();
    notifyListeners();

    try {
      await _scanner.scanAllDrives(onProgress: (p) {
        _scanProgress = p;
        notifyListeners();
      });
      // Reload from cache to get complete sorted list
      _allTracks = await PlaylistRepository.instance.getCachedTracks();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    _scanProgress = const ScanProgress(isComplete: true);
    notifyListeners();
  }

  Future<void> startIncrementalScan() async {
    _isLoading = true;
    _error = null;
    _scanProgress = const ScanProgress();
    notifyListeners();

    try {
      final newCount = await _scanner.scanIncremental(onProgress: (p) {
        _scanProgress = p;
        notifyListeners();
      });
      if (newCount > 0) {
        _allTracks = await PlaylistRepository.instance.getCachedTracks();
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    _scanProgress = const ScanProgress(isComplete: true);
    notifyListeners();
  }

  void cancelScan() {
    _scanner.cancelScan();
    _isLoading = false;
    _scanProgress = const ScanProgress(isComplete: true);
    notifyListeners();
  }

  Future<void> scanDefaultLocations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allTracks = await _scanner.scanDefaultLocations();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> scanDirectory(String path) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allTracks = await _scanner.scanDirectory(path);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Rename ──

  Future<bool> renameTrack(MusicTrack track, String newName) async {
    try {
      final parent = Directory(track.path).parent.path;
      final newPath = '$parent${Platform.pathSeparator}$newName';
      await File(track.path).rename(newPath);

      final updated = track.copyWith(
        path: newPath,
        title: newName.replaceAll(RegExp(r'\.[^.]+$'), ''),
      );

      final repo = PlaylistRepository.instance;
      await repo.removeCachedTrack(track.path);
      await repo.upsertCachedTrack(updated);
      await repo.updateTrackPath(track.path, newPath);
      AudioPlayerService.instance.replaceTrackInQueue(track.path, updated);

      final idx = _allTracks.indexWhere((t) => t.path == track.path);
      if (idx != -1) _allTracks[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[MusicLibrary] Rename failed: $e');
      return false;
    }
  }

  // ── Recent / Search ──

  void addToRecent(MusicTrack track) {
    _recentlyPlayed.remove(track);
    _recentlyPlayed.insert(0, track);
    if (_recentlyPlayed.length > 50) {
      _recentlyPlayed.removeLast();
    }
    notifyListeners();
  }

  List<MusicTrack> search(String query) {
    final q = query.toLowerCase();
    return _allTracks.where((t) {
      return t.title.toLowerCase().contains(q) ||
          (t.artist?.toLowerCase().contains(q) ?? false) ||
          (t.album?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}
