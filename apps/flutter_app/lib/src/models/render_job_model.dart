enum RenderStatus {
  queued,
  rendering,
  completed,
  failed,
  cancelled,
}

class RenderJobModel {
  final String id;
  final String name;
  final String outputPath;
  final String format;
  final String resolution;
  final String codec;
  double progress;
  RenderStatus status;
  double etaSeconds;
  String? errorMessage;

  RenderJobModel({
    required this.id,
    required this.name,
    required this.outputPath,
    this.format = 'mp4',
    this.resolution = '1920x1080',
    this.codec = 'h264',
    this.progress = 0.0,
    this.status = RenderStatus.queued,
    this.etaSeconds = 0.0,
    this.errorMessage,
  });
}
