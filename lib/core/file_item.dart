import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum FileCategory { documents, images, videos, audio, archives, code, others }

class FileItem {
  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime modified;
  final FileCategory category;

  const FileItem({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modified,
    required this.category,
  });

  factory FileItem.fromFileSystem(FileSystemEntity entity) {
    final stat = entity.statSync();
    final isDir = stat.type == FileSystemEntityType.directory;
    final ext = isDir ? '' : entity.uri.pathSegments.last.split('.').last.toLowerCase();

    return FileItem(
      path: entity.path,
      name: nameFromPath(entity.path),
      isDirectory: isDir,
      size: stat.size,
      modified: stat.modified,
      category: isDir ? FileCategory.others : _detectCategory(ext),
    );
  }

  static String nameFromPath(String path) {
    final segments = path.split(Platform.pathSeparator).where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? path : segments.last;
  }

  static FileCategory _detectCategory(String ext) {
    const docExts = {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'rtf', 'odt', 'ods'};
    const imgExts = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'svg', 'webp', 'heic', 'ico', 'tiff', 'tif'};
    const vidExts = {'mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm', 'm4v', '3gp'};
    const audExts = {'mp3', 'wav', 'aac', 'flac', 'ogg', 'wma', 'm4a', 'opus', 'aiff'};
    const arcExts = {'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso'};
    const codeExts = {'dart', 'py', 'js', 'ts', 'html', 'css', 'json', 'xml', 'yaml', 'yml', 'java', 'kt', 'swift', 'c', 'cpp', 'h', 'rs', 'go', 'rb', 'php', 'sql', 'sh', 'bat', 'ps1'};

    if (imgExts.contains(ext)) return FileCategory.images;
    if (vidExts.contains(ext)) return FileCategory.videos;
    if (audExts.contains(ext)) return FileCategory.audio;
    if (docExts.contains(ext)) return FileCategory.documents;
    if (arcExts.contains(ext)) return FileCategory.archives;
    if (codeExts.contains(ext)) return FileCategory.code;
    return FileCategory.others;
  }

  String get formattedSize {
    if (isDirectory) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(modified);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return DateFormat('yyyy-MM-dd').format(modified);
  }

  IconData get icon {
    if (isDirectory) return Icons.folder;
    return _extIcon(name.split('.').last.toLowerCase());
  }

  static IconData _extIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
      case 'odt':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'ods':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
      case 'rtf':
        return Icons.text_snippet;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'bmp':
      case 'webp':
      case 'heic':
      case 'ico':
      case 'tiff':
      case 'tif':
      case 'svg':
        return Icons.image;
      case 'gif':
        return Icons.gif;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'wmv':
      case 'flv':
      case 'webm':
      case 'm4v':
        return Icons.movie;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'flac':
      case 'ogg':
      case 'wma':
      case 'm4a':
      case 'opus':
        return Icons.music_note;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
      case 'xz':
      case 'iso':
        return Icons.archive;
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'java':
      case 'kt':
      case 'swift':
      case 'c':
      case 'cpp':
      case 'h':
      case 'rs':
      case 'go':
      case 'rb':
      case 'php':
      case 'sql':
      case 'sh':
      case 'bat':
      case 'ps1':
      case 'html':
      case 'css':
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get iconColor {
    if (isDirectory) return Colors.amber;
    switch (category) {
      case FileCategory.images:
        return Colors.pink;
      case FileCategory.videos:
        return Colors.deepPurple;
      case FileCategory.audio:
        return Colors.orange;
      case FileCategory.documents:
        return Colors.blue;
      case FileCategory.archives:
        return Colors.brown;
      case FileCategory.code:
        return Colors.teal;
      case FileCategory.others:
        return Colors.grey;
    }
  }

  bool get canGoUp {
    final parent = Directory(path).parent.path;
    return parent != path;
  }

  String get parentPath => Directory(path).parent.path;
}
