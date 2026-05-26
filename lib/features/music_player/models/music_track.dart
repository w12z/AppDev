import 'dart:io';
import '../../../core/file_item.dart';

class MusicTrack {
  final String path;
  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final int fileSize;
  final DateTime? lastModified;

  const MusicTrack({
    required this.path,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    required this.fileSize,
    this.lastModified,
  });

  factory MusicTrack.fromFileItem(FileItem item) {
    final nameWithoutExt = item.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    return MusicTrack(
      path: item.path,
      title: nameWithoutExt,
      fileSize: item.size,
      lastModified: item.modified,
    );
  }

  factory MusicTrack.fromPath(String path) {
    final file = File(path);
    final stat = file.statSync();
    final name = FileItem.nameFromPath(path);
    final nameWithoutExt = name.replaceAll(RegExp(r'\.[^.]+$'), '');
    return MusicTrack(
      path: path,
      title: nameWithoutExt,
      fileSize: stat.size,
      lastModified: stat.modified,
    );
  }

  MusicTrack copyWith({String? path, String? title}) => MusicTrack(
    path: path ?? this.path,
    title: title ?? this.title,
    artist: artist,
    album: album,
    duration: duration,
    fileSize: fileSize,
    lastModified: lastModified,
  );

  Map<String, dynamic> toJson() => {
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': duration?.inMilliseconds,
    'fileSize': fileSize,
    'lastModified': lastModified?.toIso8601String(),
  };

  factory MusicTrack.fromJson(Map<String, dynamic> json) => MusicTrack(
    path: json['path'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String?,
    album: json['album'] as String?,
    duration: json['durationMs'] != null
        ? Duration(milliseconds: json['durationMs'] as int)
        : null,
    fileSize: json['fileSize'] as int,
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'] as String)
        : null,
  );

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDuration {
    if (duration == null) return '--:--';
    final m = duration!.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration!.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration!.inHours > 0 ? '${duration!.inHours}:' : ''}$m:$s';
  }

  String get subtitle => artist ?? album ?? formattedSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MusicTrack && path == other.path;

  @override
  int get hashCode => path.hashCode;
}

class Playlist {
  final int? id;
  final String name;
  final List<String> trackPaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    this.id,
    required this.name,
    required this.trackPaths,
    required this.createdAt,
    required this.updatedAt,
  });

  int get trackCount => trackPaths.length;

  Playlist copyWith({
    int? id,
    String? name,
    List<String>? trackPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      trackPaths: trackPaths ?? this.trackPaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Playlist withReorderedTracks(int oldIndex, int newIndex) {
    final tracks = List<String>.from(trackPaths);
    final item = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, item);
    return copyWith(trackPaths: tracks, updatedAt: DateTime.now());
  }

  Playlist withAddedTrack(String path) {
    if (trackPaths.contains(path)) return this;
    return copyWith(
      trackPaths: [...trackPaths, path],
      updatedAt: DateTime.now(),
    );
  }

  Playlist withRemovedTrack(String path) {
    return copyWith(
      trackPaths: trackPaths.where((p) => p != path).toList(),
      updatedAt: DateTime.now(),
    );
  }
}

class QueuePlaylist {
  final String name;
  final List<MusicTrack> tracks;
  int currentTrackIndex;
  Duration savedPosition;

  QueuePlaylist({
    required this.name,
    required this.tracks,
    this.currentTrackIndex = 0,
    this.savedPosition = Duration.zero,
  });

  MusicTrack? get currentTrack =>
      currentTrackIndex >= 0 && currentTrackIndex < tracks.length
          ? tracks[currentTrackIndex]
          : null;

  int get trackCount => tracks.length;
}
