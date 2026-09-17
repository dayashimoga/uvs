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
  String? errorMessage;

  RenderJobModel({
    required this.id,
    required this.name,
    required this.outputPath,
    required this.format,
    required this.resolution,
    required this.codec,
    this.progress = 0.0,
    this.status = RenderStatus.queued,
    this.errorMessage,
  });
}
