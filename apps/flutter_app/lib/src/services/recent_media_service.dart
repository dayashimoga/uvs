import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class RecentMediaService extends ChangeNotifier {
  static RecentMediaService? _instance;
  static RecentMediaService get instance => _instance ??= RecentMediaService._();

  final List<String> _recentMedia = [];
  final List<String> _recentProjects = [];

  static const int maxRecentItems = 15;
  File? _storageFile;

  RecentMediaService._() {
    _initStorage();
  }

  void _initStorage() {
    try {
      final appDir = Directory.current;
      _storageFile = File('${appDir.path}/.uvs_recents.json');
      if (_storageFile!.existsSync()) {
        final content = _storageFile!.readAsStringSync();
        final data = jsonDecode(content);
        if (data is Map) {
          if (data['media'] is List) {
            _recentMedia.clear();
            for (final p in data['media']) {
              if (p is String && File(p).existsSync()) {
                _recentMedia.add(p);
              }
            }
          }
          if (data['projects'] is List) {
            _recentProjects.clear();
            for (final p in data['projects']) {
              if (p is String && File(p).existsSync()) {
                _recentProjects.add(p);
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  void _saveStorage() {
    try {
      if (_storageFile != null) {
        final data = {
          'media': _recentMedia,
          'projects': _recentProjects,
          'updated_at': DateTime.now().toIso8601String(),
        };
        _storageFile!.writeAsStringSync(jsonEncode(data));
      }
    } catch (_) {}
  }

  List<String> get recentMedia {
    _recentMedia.removeWhere((p) => !File(p).existsSync());
    return List.unmodifiable(_recentMedia);
  }

  List<String> get recentProjects {
    _recentProjects.removeWhere((p) => !File(p).existsSync());
    return List.unmodifiable(_recentProjects);
  }

  void addRecentMedia(String path) {
    if (!File(path).existsSync()) return;
    _recentMedia.remove(path);
    _recentMedia.insert(0, path);
    if (_recentMedia.length > maxRecentItems) {
      _recentMedia.removeRange(maxRecentItems, _recentMedia.length);
    }
    _saveStorage();
    notifyListeners();
  }

  void addRecentProject(String path) {
    if (!File(path).existsSync()) return;
    _recentProjects.remove(path);
    _recentProjects.insert(0, path);
    if (_recentProjects.length > maxRecentItems) {
      _recentProjects.removeRange(maxRecentItems, _recentProjects.length);
    }
    _saveStorage();
    notifyListeners();
  }

  void clearRecents() {
    _recentMedia.clear();
    _recentProjects.clear();
    _saveStorage();
    notifyListeners();
  }
}
