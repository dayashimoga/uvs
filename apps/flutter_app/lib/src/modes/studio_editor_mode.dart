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
  int _sidePanelTab = 0; // 0: Inspector, 1: Color, 2: Audio, 3: Subtitles, 4: Render Queue

  final List<RenderJobModel> _renderJobs = [];

  @override
  void initState() {
    super.initState();
    _project = ProjectModel.createDefault();
    _selectedClip = _project.tracks.first.clips.first;
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
            track.clips.removeAt(idx);
            // Ripple shift subsequent clips
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

  void _openExportDialog() {
    String format = "MP4";
    String resolution = "1080p (1920x1080)";
    String codec = "H.264 (Hardware NVENC/QSV/CPU)";

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
                        "Hardware Encoder Detected (Auto-fallback to libx264 enabled)",
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
              setState(() {
                final job = RenderJobModel(
                  id: "job-${DateTime.now().millisecondsSinceEpoch}",
                  name: "Export: ${_project.name} ($resolution)",
                  outputPath: "exports/${_project.name.toLowerCase().replaceAll(' ', '_')}.${format.toLowerCase()}",
                  format: format,
                  resolution: resolution,
                  codec: codec,
                  progress: 0.0,
                  status: RenderStatus.rendering,
                );
                _renderJobs.add(job);
                _sidePanelTab = 4; // Switch to Render Queue tab
              });
              // Simulate rendering progression
              Timer.periodic(const Duration(milliseconds: 200), (t) {
                if (!mounted) {
                  t.cancel();
                  return;
                }
                setState(() {
                  final job = _renderJobs.last;
                  job.progress += 0.2;
                  if (job.progress >= 1.0) {
                    job.progress = 1.0;
                    job.status = RenderStatus.completed;
                    t.cancel();
                  }
                });
              });
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
          child: Row(
            children: [
              Text(_project.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: StudioTheme.surfaceElevated, borderRadius: BorderRadius.circular(4)),
                child: const Text("v1.0 .uvsp", style: TextStyle(color: StudioTheme.accentCyan, fontSize: 10)),
              ),
              const Spacer(),
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

        // Middle Section: Preview Monitors (Source & Program) + Inspector Tabs
        Expanded(
          flex: 6,
          child: Row(
            children: [
              // Program Monitor Canvas
              Expanded(
                flex: 7,
                child: Container(
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
                                  // Video Surface Simulation
                                  Row(
                                    children: [
                                      Expanded(child: Container(color: const Color(0xFFC0C0C0))),
                                      Expanded(child: Container(color: const Color(0xFFC0C000))),
                                      Expanded(child: Container(color: const Color(0xFF00C0C0))),
                                      Expanded(child: Container(color: const Color(0xFF00C000))),
                                      Expanded(child: Container(color: const Color(0xFFC000C0))),
                                      Expanded(child: Container(color: const Color(0xFFC00000))),
                                      Expanded(child: Container(color: const Color(0xFF0000C0))),
                                    ],
                                  ),
                                  // Selected Clip Badge
                                  if (_selectedClip != null)
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        color: Colors.black.withOpacity(0.6),
                                        child: Text("Active: ${_selectedClip!.name}",
                                            style: const TextStyle(color: Colors.white, fontSize: 11)),
                                      ),
                                    ),
                                  // Timecode Display
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      color: Colors.black.withOpacity(0.7),
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
                    ],
                  ),
                ),
              ),

              // Side Tabbed Panel (Inspector / Color / Audio / Subtitles / Render Queue)
              Container(
                width: 340,
                color: StudioTheme.surface,
                child: Column(
                  children: [
                    // Tab Bar
                    Container(
                      height: 46,
                      color: StudioTheme.surfaceElevated,
                      child: Row(
                        children: [
                          _buildTabButton(0, "Inspector", Icons.tune),
                          _buildTabButton(1, "Color", Icons.palette),
                          _buildTabButton(2, "Audio", Icons.equalizer),
                          _buildTabButton(3, "Subtitles", Icons.subtitles),
                          _buildTabButton(4, "Queue", Icons.queue),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildSidePanelContent(),
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _sidePanelTab == index;
    return Expanded(
      child: GestureDetector(
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
      ),
    );
  }

  Widget _buildSidePanelContent() {
    switch (_sidePanelTab) {
      case 0:
        return _buildClipInspector();
      case 1:
        return const ColorInspectorView();
      case 2:
        return AudioMixerView(project: _project);
      case 3:
        return _buildSubtitleEditor();
      case 4:
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
          const Text("Subtitles & Closed Captions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                _buildSubtitleRow("00:00:00:15", "00:00:02:00", "Universal Video Studio - Production Ready"),
                _buildSubtitleRow("00:00:02:05", "00:00:04:00", "High Performance Non-Destructive Video NLE"),
              ],
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Render & Export Queue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          if (_renderJobs.isEmpty)
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
                itemCount: _renderJobs.length,
                itemBuilder: (ctx, idx) {
                  final job = _renderJobs[idx];
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
                            Text(
                              job.status == RenderStatus.completed ? "DONE" : "${(job.progress * 100).round()}%",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: job.status == RenderStatus.completed ? StudioTheme.accentEmerald : StudioTheme.accentCyan,
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
  }
}
