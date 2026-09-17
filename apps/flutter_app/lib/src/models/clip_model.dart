class ClipModel {
  final String id;
  String name;
  String mediaPath;
  double startTime;
  double duration;
  double inPoint;
  double outPoint;
  double volume;
  double opacity;
  double speed;
  double posX;
  double posY;
  double scaleX;
  double scaleY;
  double rotation;

  ClipModel({
    required this.id,
    required this.name,
    required this.mediaPath,
    required this.startTime,
    required this.duration,
    this.inPoint = 0.0,
    double? outPoint,
    this.volume = 1.0,
    this.opacity = 1.0,
    this.speed = 1.0,
    this.posX = 0.0,
    this.posY = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotation = 0.0,
  }) : outPoint = outPoint ?? duration;

  double get endTime => startTime + duration;

  bool containsTime(double time) {
    return time >= startTime && time < endTime;
  }

  ClipModel clone({String? newId, double? newStart, double? newDuration}) {
    return ClipModel(
      id: newId ?? id,
      name: name,
      mediaPath: mediaPath,
      startTime: newStart ?? startTime,
      duration: newDuration ?? duration,
      inPoint: inPoint,
      outPoint: outPoint,
      volume: volume,
      opacity: opacity,
      speed: speed,
      posX: posX,
      posY: posY,
      scaleX: scaleX,
      scaleY: scaleY,
      rotation: rotation,
    );
  }
}
