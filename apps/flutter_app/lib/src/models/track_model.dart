import 'clip_model.dart';

enum TrackType {
  video,
  audio,
  subtitle,
  adjustment,
}

class TrackModel {
  final String id;
  String name;
  final TrackType trackType;
  int zIndex;
  bool muted;
  bool solo;
  bool locked;
  double volume;
  double pan;
  List<ClipModel> clips;

  TrackModel({
    required this.id,
    required this.name,
    required this.trackType,
    this.zIndex = 0,
    this.muted = false,
    this.solo = false,
    this.locked = false,
    this.volume = 1.0,
    this.pan = 0.0,
    List<ClipModel>? clips,
  }) : clips = clips ?? [];

  double get duration {
    if (clips.isEmpty) return 0.0;
    return clips.map((c) => c.endTime).reduce((a, b) => a > b ? a : b);
  }

  ClipModel? clipAt(double time) {
    for (final c in clips) {
      if (c.containsTime(time)) return c;
    }
    return null;
  }
}
