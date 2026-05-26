import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '../models/music_track.dart';
import 'playlist_repository.dart';

class ScanProgress {
  final int filesFound;
  final int directoriesScanned;
  final String currentDirectory;
  final bool isComplete;
  final String? error;

  const ScanProgress({
    this.filesFound = 0,
    this.directoriesScanned = 0,
    this.currentDirectory = '',
    this.isComplete = false,
    this.error,
  });
}

class MusicScanner {
  static const audioExtensions = {
    'mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'wma', 'opus', 'aiff',
  };

  static const _directoryBlacklist = {
    'Windows', 'Program Files', 'Program Files (x86)', 'ProgramData',
    r'$Recycle.Bin', 'System Volume Information', 'Recovery', 'Boot',
    'MSOCache', 'PerfLogs', 'Config.Msi', 'node_modules', '.git',
    'swapfile.sys', 'pagefile.sys', 'hiberfil.sys',
  };

  static List<String> enumerateDrives() {
    if (!Platform.isWindows) return [];
    final drives = <String>[];
    for (var c = 65; c <= 90; c++) {
      final path = '${String.fromCharCode(c)}:\\';
      if (Directory(path).existsSync()) drives.add(path);
    }
    return drives;
  }

  Isolate? _isolate;

  // ── Full disk scan (Isolate) ──

  Future<int> scanAllDrives({
    required void Function(ScanProgress) onProgress,
  }) async {
    final drives = enumerateDrives();
    if (drives.isEmpty) {
      onProgress(const ScanProgress(isComplete: true));
      return 0;
    }
    return _runIsolateScan(
      directories: drives,
      skipCached: false,
      onProgress: onProgress,
    );
  }

  // ── Incremental scan (Isolate, skips already-cached paths) ──

  Future<int> scanIncremental({
    required void Function(ScanProgress) onProgress,
  }) async {
    final drives = enumerateDrives();
    if (drives.isEmpty) {
      onProgress(const ScanProgress(isComplete: true));
      return 0;
    }
    return _runIsolateScan(
      directories: drives,
      skipCached: true,
      onProgress: onProgress,
    );
  }

  Future<int> _runIsolateScan({
    required List<String> directories,
    required bool skipCached,
    required void Function(ScanProgress) onProgress,
  }) async {
    final cachedPaths = skipCached
        ? await PlaylistRepository.instance.getCachedPaths()
        : <String>{};

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_scanIsolateEntry, receivePort.sendPort);

    final completer = Completer<int>();
    final tracks = <MusicTrack>[];
    int fileCount = 0;
    int dirCount = 0;

    receivePort.listen((message) {
      final msg = message as Map<String, dynamic>;
      switch (msg['type'] as String) {
        case 'ready':
          (msg['controlPort'] as SendPort).send({
            'directories': directories,
            'blacklist': _directoryBlacklist.toList(),
            'cachedPaths': cachedPaths.toList(),
          });
          break;
        case 'progress':
          dirCount = msg['dirsScanned'] as int;
          onProgress(ScanProgress(
            filesFound: fileCount,
            directoriesScanned: dirCount,
            currentDirectory: msg['currentDir'] as String,
          ));
          break;
        case 'batch':
          final batch = (msg['tracks'] as List)
              .map((m) => MusicTrack.fromJson(m as Map<String, dynamic>))
              .toList();
          tracks.addAll(batch);
          fileCount = msg['cumulativeCount'] as int;
          dirCount = msg['dirsScanned'] as int? ?? dirCount;
          onProgress(ScanProgress(
            filesFound: fileCount,
            directoriesScanned: dirCount,
            currentDirectory: msg['currentDir'] as String? ?? '',
          ));
          break;
        case 'error':
          onProgress(ScanProgress(error: msg['message'] as String?));
          break;
        case 'complete':
          fileCount = msg['totalFiles'] as int;
          completer.complete(fileCount);
          break;
      }
    });

    final count = await completer.future;

    if (skipCached) {
      for (final t in tracks) {
        await PlaylistRepository.instance.upsertCachedTrack(t);
      }
    } else {
      if (tracks.isNotEmpty) {
        await PlaylistRepository.instance.replaceCachedTracks(tracks);
      }
    }

    for (final dir in directories) {
      await PlaylistRepository.instance.recordScanDir(dir);
    }

    onProgress(ScanProgress(isComplete: true, filesFound: count));
    return count;
  }

  // ── Single directory scan (no Isolate) ──

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

  // ── Legacy: scan default ~/Music ──

  Future<List<MusicTrack>> scanDefaultLocations() async {
    final path = _defaultMusicPath();
    if (path == null) return [];
    return scanDirectory(path);
  }

  String? _defaultMusicPath() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'];
    if (home == null) return null;
    return '$home${Platform.pathSeparator}Music';
  }

  void cancelScan() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}

// ── Isolate entry points (top-level) ──

void _scanIsolateEntry(SendPort sendPort) {
  final controlPort = ReceivePort();
  sendPort.send({'type': 'ready', 'controlPort': controlPort.sendPort});

  controlPort.listen((message) {
    final config = message as Map<String, dynamic>;
    final dirs = (config['directories'] as List).cast<String>();
    final blacklist = Set<String>.from(config['blacklist'] as List);
    final cachedPaths = Set<String>.from(config['cachedPaths'] as List);

    _executeScan(dirs, blacklist, cachedPaths, sendPort);
  });
}

void _executeScan(
  List<String> roots,
  Set<String> blacklist,
  Set<String> cachedPaths,
  SendPort sendPort,
) {
  int fileCount = 0;
  int dirsScanned = 0;
  const audioExts = {
    'mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'wma', 'opus', 'aiff',
  };

  void walk(Directory dir) {
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (blacklist.contains(name)) continue;
          dirsScanned++;
          if (dirsScanned % 20 == 0) {
            sendPort.send({
              'type': 'progress',
              'filesFound': fileCount,
              'dirsScanned': dirsScanned,
              'currentDir': entity.path,
            });
          }
          walk(entity);
        } else if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (!audioExts.contains(ext)) continue;
          if (cachedPaths.contains(entity.path)) continue;

          try {
            final stat = entity.statSync();
            final name = entity.path.split(Platform.pathSeparator).last;
            final nameWithoutExt = name.replaceAll(RegExp(r'\.[^.]+$'), '');
            fileCount++;

            sendPort.send({
              'type': 'batch',
              'tracks': [
                {
                  'path': entity.path,
                  'title': nameWithoutExt,
                  'artist': null,
                  'album': null,
                  'durationMs': null,
                  'fileSize': stat.size,
                  'lastModified': stat.modified.toIso8601String(),
                }
              ],
              'cumulativeCount': fileCount,
              'dirsScanned': dirsScanned,
              'currentDir': entity.path,
            });
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  for (final root in roots) {
    final rootDir = Directory(root);
    if (rootDir.existsSync()) {
      walk(rootDir);
    }
  }

  sendPort.send({'type': 'complete', 'totalFiles': fileCount});
}
