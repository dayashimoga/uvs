import 'track_model.dart';
import 'clip_model.dart';

class ProjectModel {
  final String id;
  String name;
  final int schemaVersion;
  int width;
  int height;
  int fpsNum;
  int fpsDen;
  final List<TrackModel> tracks;

  ProjectModel({
    required this.id,
    required this.name,
    this.schemaVersion = 1,
    this.width = 1920,
    this.height = 1080,
    this.fpsNum = 30,
    this.fpsDen = 1,
    List<TrackModel>? tracks,
  }) : tracks = tracks ?? [];

  double get duration {
    if (tracks.isEmpty) return 0.0;
    return tracks.map((t) => t.duration).reduce((a, b) => a > b ? a : b);
  }

  static ProjectModel createDefault() {
    final proj = ProjectModel(
      id: 'proj-default-001',
      name: 'Universal Studio Project',
      width: 1920,
      height: 1080,
      fpsNum: 30,
      fpsDen: 1,
    );

    // Initial tracks
    final v1 = TrackModel(id: 'track-v1', name: 'V1 - Video', trackType: TrackType.video, zIndex: 0);
    final a1 = TrackModel(id: 'track-a1', name: 'A1 - Audio', trackType: TrackType.audio, zIndex: 1);
    final sub = TrackModel(id: 'track-sub', name: 'Subtitles', trackType: TrackType.subtitle, zIndex: 2);

    // Add initial working clip
    v1.clips.add(ClipModel(
      id: 'clip-01',
      name: 'SMPTE HD Master',
      mediaPath: 'media/fixtures/test_smpte_1080p.mp4',
      startTime: 0.0,
      duration: 4.0,
    ));

    a1.clips.add(ClipModel(
      id: 'clip-a01',
      name: '1kHz Reference Tone',
      mediaPath: 'media/fixtures/test_smpte_1080p.mp4',
      startTime: 0.0,
      duration: 4.0,
    ));

    proj.tracks.addAll([v1, a1, sub]);
    return proj;
  }
}
