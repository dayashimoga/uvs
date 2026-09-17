import 'dart:async';
import 'package:flutter/foundation.dart';

enum RecordingSource {
  screen,
  camera,
  microphone,
  systemAudio,
}

class RecordingService extends ChangeNotifier {
  static RecordingService? _instance;
  static RecordingService get instance => _instance ??= RecordingService._();

  bool _isRecording = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  final Set<RecordingSource> _activeSources = {RecordingSource.screen, RecordingSource.microphone};

  bool get isRecording => _isRecording;
  int get elapsedSeconds => _elapsedSeconds;
  Set<RecordingSource> get activeSources => Set.unmodifiable(_activeSources);

  RecordingService._();

  void toggleSource(RecordingSource source) {
    if (_isRecording) return;
    if (_activeSources.contains(source)) {
      _activeSources.remove(source);
    } else {
      _activeSources.add(source);
    }
    notifyListeners();
  }

  bool startRecording() {
    if (_isRecording || _activeSources.isEmpty) return false;
    _isRecording = true;
    _elapsedSeconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  String stopRecording() {
    if (!_isRecording) return '';
    _isRecording = false;
    _timer?.cancel();
    _timer = null;
    final outputPath = 'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
    notifyListeners();
    return outputPath;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
