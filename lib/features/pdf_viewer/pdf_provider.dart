import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PdfInfo {
  final String path;
  final String name;
  final DateTime lastOpened;

  const PdfInfo({
    required this.path,
    required this.name,
    required this.lastOpened,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'lastOpened': lastOpened.toIso8601String(),
      };

  factory PdfInfo.fromJson(Map<String, dynamic> json) => PdfInfo(
        path: json['path'] as String,
        name: json['name'] as String,
        lastOpened: DateTime.parse(json['lastOpened'] as String),
      );
}

class PdfRecentService {
  static PdfRecentService? _instance;
  factory PdfRecentService() => _instance ??= PdfRecentService._();
  PdfRecentService._();

  File? _file;
  Future<File> get _configFile async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}pdf_recent.json');
    return _file!;
  }

  Future<List<PdfInfo>> getRecents() async {
    if (kIsWeb) return [];
    try {
      final file = await _configFile;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> json = jsonDecode(content);
      return json
          .map((e) => PdfInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addOrUpdate(String path, String name) async {
    if (kIsWeb) return;
    final recents = await getRecents();
    recents.removeWhere((r) => r.path == path);
    recents.insert(0, PdfInfo(path: path, name: name, lastOpened: DateTime.now()));
    if (recents.length > 50) {
      recents.removeRange(50, recents.length);
    }
    await _save(recents);
  }

  Future<void> remove(String path) async {
    if (kIsWeb) return;
    final recents = await getRecents();
    recents.removeWhere((r) => r.path == path);
    await _save(recents);
  }

  Future<void> clearAll() async {
    if (kIsWeb) return;
    await _save([]);
  }

  Future<void> _save(List<PdfInfo> recents) async {
    if (kIsWeb) return;
    final file = await _configFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(recents.map((r) => r.toJson()).toList()),
    );
  }
}

class PdfProvider extends ChangeNotifier {
  final PdfRecentService _service = PdfRecentService();

  List<PdfInfo> _recentPdfs = [];
  bool _loading = true;

  List<PdfInfo> get recentPdfs => _recentPdfs;
  bool get loading => _loading;

  PdfProvider() {
    loadRecents();
  }

  Future<void> loadRecents() async {
    if (kIsWeb) {
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    _recentPdfs = await _service.getRecents();
    _loading = false;
    notifyListeners();
  }

  Future<void> recordOpen(String path, String name) async {
    if (kIsWeb) return;
    await _service.addOrUpdate(path, name);
    await loadRecents();
  }

  Future<void> removeRecent(String path) async {
    if (kIsWeb) return;
    await _service.remove(path);
    await loadRecents();
  }

  Future<void> clearRecents() async {
    if (kIsWeb) return;
    await _service.clearAll();
    await loadRecents();
  }
}
