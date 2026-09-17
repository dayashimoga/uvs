import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/ffi_bridge.dart';

class ProjectService extends ChangeNotifier {
  static ProjectService? _instance;
  static ProjectService get instance => _instance ??= ProjectService._();

  Map<String, dynamic> _project = {};
  String? _currentFilePath;
  bool _isDirty = false;
  Timer? _autosaveTimer;

  Map<String, dynamic> get project => _project;
  String? get currentFilePath => _currentFilePath;
  bool get isDirty => _isDirty;

  ProjectService._() {
    newProject();
    _startAutosave();
  }

  void _startAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_isDirty && _currentFilePath != null) {
        saveProject(_currentFilePath!);
      }
    });
  }

  void newProject({
    String name = 'Untitled Project',
    int width = 1920,
    int height = 1080,
    int fpsNum = 30,
    int fpsDen = 1,
    bool dropFrame = false,
  }) {
    _project = UvsFfiBridge.instance.createProject(
      name: name,
      width: width,
      height: height,
      fpsNum: fpsNum,
      fpsDen: fpsDen,
      dropFrame: dropFrame,
    );
    _currentFilePath = null;
    _isDirty = false;
    notifyListeners();
  }

  bool loadProject(String path) {
    final loaded = UvsFfiBridge.instance.loadProject(path);
    if (loaded.containsKey('error')) {
      return false;
    }
    _project = loaded;
    _currentFilePath = path;
    _isDirty = false;
    notifyListeners();
    return true;
  }

  bool saveProject(String path) {
    final res = UvsFfiBridge.instance.saveProjectAtomic(_project, path);
    if (res.containsKey('error')) {
      return false;
    }
    _currentFilePath = path;
    _isDirty = false;
    notifyListeners();
    return true;
  }

  int relinkAssets(String searchDir) {
    final res = UvsFfiBridge.instance.relinkProject(_project, searchDir);
    final count = res['relinked_count'] as int? ?? 0;
    if (count > 0) {
      _project = res['project'] as Map<String, dynamic>;
      _isDirty = true;
      notifyListeners();
    }
    return count;
  }

  void addTrack(String name, String trackType, int zIndex) {
    _project = UvsFfiBridge.instance.timelineAddTrack(_project, name, trackType, zIndex);
    _isDirty = true;
    notifyListeners();
  }

  void addClip(String trackId, String clipName, String mediaPath, double startS, double durationS) {
    _project = UvsFfiBridge.instance.timelineAddClip(_project, trackId, clipName, mediaPath, startS, durationS);
    _isDirty = true;
    notifyListeners();
  }

  void splitClip(String trackId, String clipId, double splitTimeS) {
    _project = UvsFfiBridge.instance.timelineSplitClip(_project, trackId, clipId, splitTimeS);
    _isDirty = true;
    notifyListeners();
  }

  void rippleDelete(String trackId, String clipId) {
    _project = UvsFfiBridge.instance.timelineRippleDelete(_project, trackId, clipId);
    _isDirty = true;
    notifyListeners();
  }

  void rollEdit(String trackId, String leftClipId, String rightClipId, double deltaS) {
    _project = UvsFfiBridge.instance.timelineRollEdit(_project, trackId, leftClipId, rightClipId, deltaS);
    _isDirty = true;
    notifyListeners();
  }

  void slipEdit(String trackId, String clipId, double deltaS) {
    _project = UvsFfiBridge.instance.timelineSlipEdit(_project, trackId, clipId, deltaS);
    _isDirty = true;
    notifyListeners();
  }

  void slideEdit(String trackId, String clipId, double deltaS) {
    _project = UvsFfiBridge.instance.timelineSlideEdit(_project, trackId, clipId, deltaS);
    _isDirty = true;
    notifyListeners();
  }

  void setClipSpeed(String trackId, String clipId, double speed, bool reverse) {
    _project = UvsFfiBridge.instance.timelineSetSpeed(_project, trackId, clipId, speed, reverse);
    _isDirty = true;
    notifyListeners();
  }

  void addMarker(double timeS, String name, String color, String comment) {
    _project = UvsFfiBridge.instance.timelineAddMarker(_project, timeS, name, color, comment);
    _isDirty = true;
    notifyListeners();
  }

  void insertMulticamCuts(List<Map<String, dynamic>> cuts) {
    if (cuts.isEmpty) return;
    final timeline = _project['timeline'] as Map<String, dynamic>? ?? {};
    final tracks = (timeline['tracks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    var vTrack = tracks.firstWhere((t) => t['track_type'] == 'Video', orElse: () => {});
    if (vTrack.isEmpty) {
      addTrack('V1', 'Video', 0);
    }
    final updatedTracks = ((_project['timeline']?['tracks'] as List?)?.cast<Map<String, dynamic>>() ?? []);
    final vTrackId = updatedTracks.firstWhere((t) => t['track_type'] == 'Video')['id'] as String? ?? 'track-v1';

    for (int i = 0; i < cuts.length; i++) {
      final cut = cuts[i];
      final start = (cut['time_s'] as num?)?.toDouble() ?? (i * 4.0);
      final dur = (i + 1 < cuts.length)
          ? (((cuts[i + 1]['time_s'] as num?)?.toDouble() ?? (start + 4.0)) - start)
          : 4.0;
      final name = cut['name'] as String? ?? 'Angle Cut ${i + 1}';
      final path = cut['media_path'] as String? ?? 'media_${i + 1}.mp4';
      addClip(vTrackId, name, path, start, dur > 0 ? dur : 4.0);
    }
    _isDirty = true;
    notifyListeners();
  }


  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
}
