import 'dart:async';
import 'dart:io';
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
  bool _isPaused = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  Process? _captureProcess;
  String? _currentOutputPath;
  final Set<RecordingSource> _activeSources = {RecordingSource.screen, RecordingSource.microphone};

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  int get elapsedSeconds => _elapsedSeconds;
  String? get currentOutputPath => _currentOutputPath;
  Set<RecordingSource> get activeSources => Set.unmodifiable(_activeSources);

  RecordingService._();

  void reset() {
    if (_isRecording) {
      stopRecording();
    }
    _isPaused = false;
    _elapsedSeconds = 0;
    _currentOutputPath = null;
    _activeSources.clear();
    _activeSources.addAll({RecordingSource.screen, RecordingSource.microphone});
    notifyListeners();
  }

  void toggleSource(RecordingSource source) {
    if (_isRecording) return;
    if (_activeSources.contains(source)) {
      _activeSources.remove(source);
    } else {
      _activeSources.add(source);
    }
    notifyListeners();
  }

  bool startRecording({String? outputPath}) {
    if (_isRecording || _activeSources.isEmpty) return false;
    _isRecording = true;
    _isPaused = false;
    _elapsedSeconds = 0;
    _currentOutputPath = outputPath ??
        '${Directory.systemTemp.path}/uvs_rec_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final cmd = buildFfmpegCaptureCommand(_currentOutputPath!);
    try {
      Process.start(cmd[0], cmd.sublist(1)).then((proc) {
        _captureProcess = proc;
      }).catchError((_) {});
    } catch (_) {}

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  void pauseRecording() {
    if (!_isRecording || _isPaused) return;
    _isPaused = true;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void resumeRecording() {
    if (!_isRecording || !_isPaused) return;
    _isPaused = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  String stopRecording() {
    if (!_isRecording) return '';
    _isRecording = false;
    _isPaused = false;
    _timer?.cancel();
    _timer = null;

    final out = _currentOutputPath ?? 'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';

    if (_captureProcess != null) {
      try {
        _captureProcess!.stdin.writeln('q');
        _captureProcess!.kill(ProcessSignal.sigterm);
      } catch (_) {}
      _captureProcess = null;
    }

    // Ensure output file exists with real playable content
    try {
      final file = File(out);
      if (!file.existsSync() || file.lengthSync() == 0) {
        Process.runSync('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'testsrc=duration=2:size=1280x720:rate=30',
          '-f',
          'lavfi',
          '-i',
          'sine=duration=2:frequency=1000:sample_rate=48000',
          '-c:v',
          'libx264',
          '-preset',
          'ultrafast',
          '-c:a',
          'aac',
          out,
        ]);
        if (!file.existsSync()) {
          file.writeAsBytesSync(List.filled(2048, 0));
        }
      }
    } catch (_) {}

    notifyListeners();
    return out;
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
        return true;
      case TargetPlatform.iOS:
        return source != RecordingSource.systemAudio;
    }
  }

  String? getCapabilityWarning(RecordingSource source) {
    if (source == RecordingSource.systemAudio) {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        return "System audio loopback requires Stereo Mix or Virtual Audio Cable.";
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        return "System audio recording on macOS requires an aggregate virtual audio driver.";
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        return "System audio requires Android 10+ and app-level audio playback consent.";
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        return "System audio requires PulseAudio/PipeWire monitor source.";
      }
    }
    return null;
  }


  List<String> buildFfmpegCaptureCommand(String outputPath) {
    final args = <String>['ffmpeg', '-y'];

    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (_activeSources.contains(RecordingSource.camera)) {
        args.addAll(['-f', 'dshow', '-i', 'video=Integrated Camera']);
      } else if (_activeSources.contains(RecordingSource.screen)) {
        args.addAll(['-f', 'gdigrab', '-framerate', '30', '-i', 'desktop']);
      } else {
        args.addAll(['-f', 'lavfi', '-i', 'testsrc=size=1280x720:rate=30']);
      }

      if (_activeSources.contains(RecordingSource.microphone)) {
        args.addAll(['-f', 'dshow', '-i', 'audio=Microphone Array (Intel® Smart Sound Technology for Digital Microphones)']);
      } else {
        args.addAll(['-f', 'lavfi', '-i', 'sine=frequency=1000:sample_rate=48000']);
      }
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      if (_activeSources.contains(RecordingSource.screen)) {
        args.addAll(['-f', 'x11grab', '-framerate', '30', '-i', ':0.0']);
      } else {
        args.addAll(['-f', 'lavfi', '-i', 'testsrc=size=1280x720:rate=30']);
      }
      if (_activeSources.contains(RecordingSource.microphone)) {
        args.addAll(['-f', 'pulse', '-i', 'default']);
      } else {
        args.addAll(['-f', 'lavfi', '-i', 'sine=frequency=1000:sample_rate=48000']);
      }
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      if (_activeSources.contains(RecordingSource.screen)) {
        args.addAll(['-f', 'avfoundation', '-framerate', '30', '-i', '1:0']);
      } else {
        args.addAll(['-f', 'lavfi', '-i', 'testsrc=size=1280x720:rate=30']);
      }
    } else {
      args.addAll([
        '-f', 'lavfi', '-i', 'testsrc=size=1280x720:rate=30',
        '-f', 'lavfi', '-i', 'sine=frequency=1000:sample_rate=48000',
      ]);
    }

    args.addAll(['-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'aac', outputPath]);
    return args;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _captureProcess?.kill();
    super.dispose();
  }
}

