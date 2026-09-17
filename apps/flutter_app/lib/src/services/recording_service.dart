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

  bool isSourceSupported(RecordingSource source) {
    if (kIsWeb) {
      return source != RecordingSource.systemAudio;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.fuchsia:
        return true;
      case TargetPlatform.android:
        // System audio capture on Android requires API 29+ (Android 10+)
        return true;
      case TargetPlatform.iOS:
        return source != RecordingSource.systemAudio;
    }
  }

  String? getCapabilityWarning(RecordingSource source) {
    if (source == RecordingSource.systemAudio) {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        return "System audio recording on macOS requires an aggregate virtual audio driver.";
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        return "System audio requires Android 10+ and app-level audio playback consent.";
      }
    }
    return null;
  }

  List<String> buildFfmpegCaptureCommand(String outputPath) {
    final args = <String>['ffmpeg', '-y'];

    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (_activeSources.contains(RecordingSource.screen)) {
        args.addAll(['-f', 'gdigrab', '-framerate', '30', '-i', 'desktop']);
      }
      if (_activeSources.contains(RecordingSource.microphone)) {
        args.addAll(['-f', 'dshow', '-i', 'audio=default']);
      }
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      if (_activeSources.contains(RecordingSource.screen)) {
        args.addAll(['-f', 'x11grab', '-framerate', '30', '-i', ':0.0']);
      }
      if (_activeSources.contains(RecordingSource.microphone)) {
        args.addAll(['-f', 'pulse', '-i', 'default']);
      }
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      if (_activeSources.contains(RecordingSource.screen)) {
        args.addAll(['-f', 'avfoundation', '-framerate', '30', '-i', '1:0']);
      }
    }

    args.addAll(['-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'aac', outputPath]);
    return args;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

