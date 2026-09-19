import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/timecode.dart';
import '../models/project_model.dart';
import '../models/clip_model.dart';
import '../models/render_job_model.dart';
import '../widgets/timeline_view.dart';
import '../widgets/audio_mixer_view.dart';
import '../widgets/color_inspector_view.dart';
import '../services/project_service.dart';
import '../services/render_service.dart';
import '../models/track_model.dart';
import '../widgets/video_monitor_surface.dart';
import '../widgets/media_bin_view.dart';

class StudioEditorModeView extends StatefulWidget {
  const StudioEditorModeView({super.key});

  @override
  State<StudioEditorModeView> createState() => _StudioEditorModeViewState();
}

class _StudioEditorModeViewState extends State<StudioEditorModeView> {
  late ProjectModel _project;
  double _playheadTime = 0.0;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  ClipModel? _selectedClip;
  int _sidePanelTab = 0; // 0: Media Bin, 1: Inspector, 2: Color, 3: Audio, 4: Subtitles, 5: Render Queue
  final List<MediaBinItem> _mediaBinItems = [];

  final List<Map<String, String>> _subtitleCues = [
    {"in": "00:00:00:15", "out": "00:00:02:00", "text": "Universal Video Studio Title Cue 1"},
    {"in": "00:00:02:05", "out": "00:00:04:00", "text": "High Performance Non-Destructive Video NLE"},
  ];

  @override
  void initState() {
    super.initState();
    _project = ProjectModel.createDefault();
    if (_project.tracks.isNotEmpty && _project.tracks.first.clips.isNotEmpty) {
      _selectedClip = _project.tracks.first.clips.first;
      _mediaBinItems.add(MediaBinItem(
        id: 'bin-default-01',
        path: _selectedClip!.mediaPath,
        name: _selectedClip!.name,
        duration: _selectedClip!.duration,
        width: 1920,
        height: 1080,
        fps: 30.0,
        channels: 2,
      ));
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _playbackTimer = Timer.periodic(const Duration(milliseconds: 33), (t) {
          if (!mounted) return;
          setState(() {
            _playheadTime += 0.0333;
            if (_playheadTime >= _project.duration) {
              _playheadTime = 0.0;
              _isPlaying = false;
              _playbackTimer?.cancel();
            }
          });
        });
      } else {
        _playbackTimer?.cancel();
      }
    });
  }

  void _splitAtPlayhead() {
    if (_selectedClip != null && _selectedClip!.containsTime(_playheadTime)) {
      setState(() {
        final track = _project.tracks.firstWhere((t) => t.clips.contains(_selectedClip));
        final splitPoint = _playheadTime;
        final origDuration = _selectedClip!.duration;
        final firstDur = splitPoint - _selectedClip!.startTime;
        final secondDur = origDuration - firstDur;

        _selectedClip!.duration = firstDur;
        _selectedClip!.outPoint = _selectedClip!.inPoint + firstDur;

        final newClip = _selectedClip!.clone(
          newId: 'clip-split-${DateTime.now().millisecondsSinceEpoch}',
          newStart: splitPoint,
          newDuration: secondDur,
        );
        track.clips.add(newClip);
        track.clips.sort((a, b) => a.startTime.compareTo(b.startTime));

        ProjectService.instance.splitClip(track.id, _selectedClip!.id, splitPoint);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Clip split at ${TimecodeHelper.formatDurationSeconds(_playheadTime)}")),
      );
    }
  }

  void _rippleDeleteSelected() {
    if (_selectedClip != null) {
      setState(() {
        for (final track in _project.tracks) {
          if (track.clips.contains(_selectedClip)) {
            final idx = track.clips.indexOf(_selectedClip!);
            final removedDur = _selectedClip!.duration;
            ProjectService.instance.rippleDelete(track.id, _selectedClip!.id);
            track.clips.removeAt(idx);
            for (int i = idx; i < track.clips.length; i++) {
              track.clips[i].startTime -= removedDur;
            }
            break;
          }
        }
        _selectedClip = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Clip ripple deleted")),
      );
    }
  }

  void _addMediaBinItemToTimeline(MediaBinItem item) {
    setState(() {
      final vTrack = _project.tracks.firstWhere(
        (t) => t.trackType == TrackType.video,
        orElse: () => _project.tracks.first,
      );
      final newClip = ClipModel(
        id: 'clip-${DateTime.now().millisecondsSinceEpoch}',
        name: item.name,
        mediaPath: item.path,
        startTime: _playheadTime,
        duration: item.duration > 0 ? item.duration : 4.0,
      );
      vTrack.clips.add(newClip);
      vTrack.clips.sort((a, b) => a.startTime.compareTo(b.startTime));
      _selectedClip = newClip;

      ProjectService.instance.addClip(
        vTrack.id,
        newClip.name,
        newClip.mediaPath,
        newClip.startTime,
        newClip.duration,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Added '${item.name}' to Timeline at ${TimecodeHelper.formatDurationSeconds(_playheadTime)}")),
    );
  }

  void _openExportDialog() {
    String format = "MP4";
    String resolution = "1080p (1920x1080)";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StudioTheme.surfaceElevated,
        title: const Row(
          children: [
            Icon(Icons.output, color: StudioTheme.accentCyan),
            SizedBox(width: 8),
            Text("Export Project / Render Queue"),
          ],
        ),
        content: StatefulBuilder(
          builder: (ctx, setDlgState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Container Format", style: TextStyle(fontSize: 12, color: StudioTheme.textSecondary)),
              DropdownButton<String>(
                isExpanded: true,
                value: format,
                dropdownColor: StudioTheme.surfaceHighlight,
                items: ["MP4", "MKV", "WebM", "MOV"].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) {
                  if (v != null) setDlgState(() => format = v);
                },
              ),
              const SizedBox(height: 12),
              const Text("Resolution Preset", style: TextStyle(fontSize: 12, color: StudioTheme.textSecondary)),
              DropdownButton<String>(
                isExpanded: true,
                value: resolution,
                dropdownColor: StudioTheme.surfaceHighlight,
                items: [
                  "1080p (1920x1080)",
                  "4K UHD (3840x2160)",
                  "Reels / Shorts (1080x1920)",
                  "Square 1:1 (1080x1080)"
                ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) {
                  if (v != null) setDlgState(() => resolution = v);
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: StudioTheme.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: StudioTheme.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: StudioTheme.accentEmerald),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Hardware Transcode Engine Ready (NVENC / Intel QSV / MediaCodec / libx264)",
                        style: TextStyle(fontSize: 11, color: StudioTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: StudioTheme.accentCyan,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final inputMedia = _selectedClip?.mediaPath ?? 'sample_video.mp4';
              final outPath = "exports/${_project.name.toLowerCase().replaceAll(' ', '_')}.${format.toLowerCase()}";
              RenderService.instance.queueRender(
                name: "Export: ${_project.name} ($resolution)",
                outputPath: outPath,
                project: ProjectService.instance.project,
                inputPath: inputMedia,
              );
              setState(() {
                _sidePanelTab = 5; // Switch to Render Queue tab
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Queued render to $outPath")),
              );
            },
            child: const Text("Start Render"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const timecode = TimecodeHelper(fpsNum: 30, fpsDen: 1);

    return Column(
      children: [
        // Top Studio Action Bar
        Container(
          height: 44,
          color: StudioTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(_project.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: StudioTheme.surfaceElevated, borderRadius: BorderRadius.circular(4)),
                  child: const Text("v1.0 .uvsp", style: TextStyle(color: StudioTheme.accentCyan, fontSize: 10)),
                ),
                const SizedBox(width: 16),
                // Undo & Redo
                AnimatedBuilder(
                  animation: ProjectService.instance,
                  builder: (ctx, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.undo, size: 18),
                          tooltip: "Undo (Ctrl+Z)",
                          onPressed: ProjectService.instance.canUndo
                              ? () {
                                  ProjectService.instance.undo();
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Undo applied"), duration: Duration(milliseconds: 600)),
                                  );
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.redo, size: 18),
                          tooltip: "Redo (Ctrl+Y)",
                          onPressed: ProjectService.instance.canRedo
                              ? () {
                                  ProjectService.instance.redo();
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Redo applied"), duration: Duration(milliseconds: 600)),
                                  );
                                }
                              : null,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text("Export Video"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudioTheme.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: _openExportDialog,
                ),
              ],
            ),
          ),
        ),

        // Middle Section: Preview Monitors (Source & Program) + Inspector Tabs
        Expanded(
          flex: 6,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 750;
              final programMonitor = _buildProgramMonitor(timecode);
              final sidePanel = _buildSidePanel();

              if (isCompact) {
                return Column(
                  children: [
                    Expanded(flex: 5, child: programMonitor),
                    Expanded(flex: 5, child: sidePanel),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 7, child: programMonitor),
                  SizedBox(width: 340, child: sidePanel),
                ],
              );
            },
          ),
        ),

        // Bottom Section: Multi-Track Timeline
        Expanded(
          flex: 4,
          child: TimelineView(
            project: _project,
            playheadTime: _playheadTime,
            selectedClip: _selectedClip,
            onPlayheadSeek: (time) => setState(() => _playheadTime = time),
            onClipSelected: (clip) => setState(() => _selectedClip = clip),
            onSplitAtPlayhead: _splitAtPlayhead,
            onRippleDeleteSelected: _rippleDeleteSelected,
          ),
        ),
      ],
    );
  }

  Widget _buildProgramMonitor(TimecodeHelper timecode) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: StudioTheme.surfaceElevated,
                    border: Border.all(color: StudioTheme.border),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: VideoMonitorSurface(
                          mediaPath: _selectedClip?.mediaPath,
                          currentTime: _playheadTime,
                          duration: _project.duration,
                          isPlaying: _isPlaying,
                        ),
                      ),
                      // Selected Clip Badge
                      if (_selectedClip != null)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: StudioTheme.accentCyan),
                            ),
                            child: Text(
                              "${_selectedClip!.name} (${_selectedClip!.speed}x, opacity: ${(_selectedClip!.opacity * 100).round()}%)",
                              style: const TextStyle(fontSize: 12, color: StudioTheme.accentCyan, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      // Subtitle rendering preview
                      if (_subtitleCues.isNotEmpty)
                        Positioned(
                          bottom: 24,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            color: Colors.black.withOpacity(0.75),
                            child: Text(
                              _subtitleCues.last["text"] ?? "",
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      // Timecode HUD
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            timecode.formatTimecode(_playheadTime),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: StudioTheme.accentCyan,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Transport Bar
          Container(
            height: 40,
            color: StudioTheme.surfaceElevated,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 20),
                    onPressed: () => setState(() => _playheadTime = 0.0),
                  ),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 24, color: StudioTheme.accentCyan),
                    onPressed: _togglePlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 20),
                    onPressed: () => setState(() => _playheadTime = _project.duration),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "${timecode.formatTimecode(_playheadTime)} / ${timecode.formatTimecode(_project.duration)}",
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: StudioTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      color: StudioTheme.surface,
      child: Column(
        children: [
          // Tab Bar
          Container(
            height: 46,
            color: StudioTheme.surfaceElevated,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(width: 56, child: _buildTabButton(0, "Media", Icons.video_library)),
                  SizedBox(width: 58, child: _buildTabButton(1, "Inspector", Icons.tune)),
                  SizedBox(width: 54, child: _buildTabButton(2, "Color", Icons.palette)),
                  SizedBox(width: 54, child: _buildTabButton(3, "Audio", Icons.equalizer)),
                  SizedBox(width: 56, child: _buildTabButton(4, "Subtitles", Icons.subtitles)),
                  SizedBox(width: 54, child: _buildTabButton(5, "Queue", Icons.queue)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildSidePanelContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _sidePanelTab == index;
    return GestureDetector(
      onTap: () => setState(() => _sidePanelTab = index),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? StudioTheme.surface : Colors.transparent,
          border: Border(bottom: BorderSide(color: isSelected ? StudioTheme.accentCyan : Colors.transparent, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? StudioTheme.accentCyan : StudioTheme.textSecondary),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, color: isSelected ? StudioTheme.accentCyan : StudioTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanelContent() {
    switch (_sidePanelTab) {
      case 0:
        return MediaBinView(
          items: _mediaBinItems,
          onItemsChanged: (items) => setState(() {
            _mediaBinItems.clear();
            _mediaBinItems.addAll(items);
          }),
          onSelectPreview: (item) {
            setState(() {
              _playheadTime = 0.0;
            });
          },
          onAddToTimeline: _addMediaBinItemToTimeline,
        );
      case 1:
        return _buildClipInspector();
      case 2:
        return const ColorInspectorView();
      case 3:
        return AudioMixerView(project: _project);
      case 4:
        return _buildSubtitleEditor();
      case 5:
        return _buildRenderQueue();
      default:
        return _buildClipInspector();
    }
  }

  Widget _buildClipInspector() {
    if (_selectedClip == null) {
      return const Center(
        child: Text("Select a clip on the timeline to edit properties", style: TextStyle(color: StudioTheme.textMuted, fontSize: 12)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Text("Clip: ${_selectedClip!.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Divider(color: StudioTheme.border, height: 16),
          // Opacity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Opacity", style: TextStyle(fontSize: 12, color: StudioTheme.textSecondary)),
              Text("${(_selectedClip!.opacity * 100).round()}%", style: const TextStyle(color: StudioTheme.accentCyan, fontSize: 12)),
            ],
          ),
          Slider(
            value: _selectedClip!.opacity,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => setState(() => _selectedClip!.opacity = v),
          ),
          // Scale
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Scale", style: TextStyle(fontSize: 12, color: StudioTheme.textSecondary)),
              Text("${_selectedClip!.scaleX.toStringAsFixed(2)}x", style: const TextStyle(color: StudioTheme.accentCyan, fontSize: 12)),
            ],
          ),
          Slider(
            value: _selectedClip!.scaleX,
            min: 0.2,
            max: 3.0,
            onChanged: (v) => setState(() {
              _selectedClip!.scaleX = v;
              _selectedClip!.scaleY = v;
            }),
          ),
          // Volume
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Volume Gain", style: TextStyle(fontSize: 12, color: StudioTheme.textSecondary)),
              Text("${(_selectedClip!.volume * 100).round()}%", style: const TextStyle(color: StudioTheme.accentCyan, fontSize: 12)),
            ],
          ),
          Slider(
            value: _selectedClip!.volume,
            min: 0.0,
            max: 2.0,
            onChanged: (v) => setState(() => _selectedClip!.volume = v),
          ),
          const SizedBox(height: 8),
          const Text("Keyframes & Transitions", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_chart, size: 14),
                  label: const Text("Add Keyframe", style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(backgroundColor: StudioTheme.surfaceElevated),
                  onPressed: () {
                    final track = _project.tracks.firstWhere((t) => t.clips.contains(_selectedClip));
                    ProjectService.instance.addKeyframe(
                      track.id,
                      _selectedClip!.id,
                      'opacity',
                      _playheadTime,
                      _selectedClip!.opacity,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Keyframe added at ${TimecodeHelper.formatDurationSeconds(_playheadTime)}")),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text("Cross Dissolve", style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(backgroundColor: StudioTheme.surfaceElevated),
                  onPressed: () {
                    final track = _project.tracks.firstWhere((t) => t.clips.contains(_selectedClip));
                    ProjectService.instance.setTransition(
                      track.id,
                      _selectedClip!.id,
                      'CrossDissolve',
                      1.0,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Set Cross Dissolve transition")),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text("Precision Trimming (Slip / Slide)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final track = _project.tracks.firstWhere((t) => t.clips.contains(_selectedClip));
                    ProjectService.instance.slipEdit(track.id, _selectedClip!.id, -0.5);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Slipped clip -0.5s")));
                  },
                  child: const Text("Slip -0.5s", style: TextStyle(fontSize: 10)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final track = _project.tracks.firstWhere((t) => t.clips.contains(_selectedClip));
                    ProjectService.instance.slideEdit(track.id, _selectedClip!.id, 0.5);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Slid clip +0.5s")));
                  },
                  child: const Text("Slide +0.5s", style: TextStyle(fontSize: 10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleEditor() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "Subtitles & Closed Captions",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: StudioTheme.accentCyan, size: 20),
                tooltip: "Add Cue at Playhead",
                onPressed: () {
                  final inTc = const TimecodeHelper(fpsNum: 30, fpsDen: 1).formatTimecode(_playheadTime);
                  final outTc = const TimecodeHelper(fpsNum: 30, fpsDen: 1).formatTimecode(_playheadTime + 2.0);
                  setState(() {
                    _subtitleCues.add({
                      "in": inTc,
                      "out": outTc,
                      "text": "New Subtitle Cue at $inTc",
                    });
                  });
                  ProjectService.instance.addSubtitleCue(_playheadTime, _playheadTime + 2.0, "New Subtitle Cue");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Added subtitle cue: at $inTc")),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _subtitleCues.length,
              itemBuilder: (ctx, idx) {
                final cue = _subtitleCues[idx];
                return _buildSubtitleRow(cue["in"]!, cue["out"]!, cue["text"]!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleRow(String inTc, String outTc, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: StudioTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: StudioTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(inTc, style: const TextStyle(fontSize: 10, color: StudioTheme.accentCyan, fontFamily: 'monospace')),
              const Icon(Icons.arrow_forward, size: 10, color: StudioTheme.textMuted),
              Text(outTc, style: const TextStyle(fontSize: 10, color: StudioTheme.accentCyan, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRenderQueue() {
    return AnimatedBuilder(
      animation: RenderService.instance,
      builder: (context, _) {
        final jobs = RenderService.instance.jobs;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "Render & Export Queue",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (jobs.any((j) => j.status == RenderStatus.completed || j.status == RenderStatus.cancelled))
                    TextButton(
                      onPressed: () => RenderService.instance.clearCompleted(),
                      child: const Text("Clear Done", style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (jobs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text("No jobs in queue. Click 'Export Video' to start render.",
                        style: TextStyle(color: StudioTheme.textMuted, fontSize: 12)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: jobs.length,
                    itemBuilder: (ctx, idx) {
                      final job = jobs[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: StudioTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: StudioTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(job.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                if (job.status == RenderStatus.rendering)
                                  IconButton(
                                    icon: const Icon(Icons.cancel, size: 16, color: StudioTheme.accentRed),
                                    tooltip: "Cancel Render",
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => RenderService.instance.cancelJob(job.id),
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  job.status == RenderStatus.completed
                                      ? "DONE"
                                      : (job.status == RenderStatus.cancelled ? "CANCELLED" : "${(job.progress * 100).round()}%"),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: job.status == RenderStatus.completed
                                        ? StudioTheme.accentEmerald
                                        : (job.status == RenderStatus.cancelled ? StudioTheme.accentRed : StudioTheme.accentCyan),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: job.progress,
                              backgroundColor: StudioTheme.surfaceHighlight,
                              color: job.status == RenderStatus.completed ? StudioTheme.accentEmerald : StudioTheme.accentCyan,
                            ),
                            const SizedBox(height: 4),
                            Text(job.outputPath, style: const TextStyle(fontSize: 10, color: StudioTheme.textMuted)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
