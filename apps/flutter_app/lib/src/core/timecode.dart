class TimecodeHelper {
  final int fpsNum;
  final int fpsDen;
  final bool dropFrame;

  const TimecodeHelper({
    this.fpsNum = 30,
    this.fpsDen = 1,
    this.dropFrame = false,
  });

  double get fps => fpsNum / fpsDen;

  int secondsToFrames(double seconds) {
    return (seconds * fps).round();
  }

  double framesToSeconds(int frames) {
    return frames / fps;
  }

  String formatTimecode(double seconds) {
    int totalFrames = secondsToFrames(seconds);
    if (totalFrames < 0) totalFrames = 0;

    int fpsInt = fps.round();
    if (fpsInt <= 0) fpsInt = 30;

    int frames = totalFrames % fpsInt;
    int totalSeconds = totalFrames ~/ fpsInt;
    int s = totalSeconds % 60;
    int m = (totalSeconds ~/ 60) % 60;
    int h = totalSeconds ~/ 3600;

    String sep = dropFrame ? ';' : ':';
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}$sep${frames.toString().padLeft(2, '0')}';
  }

  static String formatDurationSeconds(double seconds) {
    int totalSec = seconds.floor();
    int m = (totalSec ~/ 60) % 60;
    int s = totalSec % 60;
    int ms = ((seconds - totalSec) * 10).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.$ms';
  }
}
