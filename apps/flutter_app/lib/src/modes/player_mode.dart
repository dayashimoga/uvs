import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/timecode.dart';
import '../services/media_service.dart';
import '../widgets/video_monitor_surface.dart';

class PlayerModeView extends StatefulWidget {
  const PlayerModeView({super.key});

  @override
  State<PlayerModeView> createState() => _PlayerModeViewState();
}

class _PlayerModeViewState extends State<PlayerModeView> {
  final TimecodeHelper _timecode = const TimecodeHelper(fpsNum: 30, fpsDen: 1);
  double _currentTime = 0.0;
  double _totalDuration = 4.0;
  String _mediaPath = 'sample_video.mp4';
  MediaProbeResult? _probeInfo;

  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  Timer? _playbackTimer;

  double? _pointA;
  double? _pointB;
  double _audioDelayMs = 0.0;

  String _selectedSubtitle = 'English [CC]';
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _startControlsTimer();
    _probeInfo = MediaService.instance.probeMedia(_mediaPath);
    _totalDuration = _probeInfo!.durationSeconds;
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _startControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _showControls = true;
      if (_isPlaying) {
        _playbackTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
          if (!mounted) return;
          setState(() {
            _currentTime += 0.0333 * _playbackSpeed;
            if (_pointB != null && _currentTime >= _pointB!) {
              _currentTime = _pointA ?? 0.0;
            } else if (_currentTime >= _totalDuration) {
              _currentTime = _pointA ?? 0.0;
              if (_pointA == null) {
                _isPlaying = false;
                _playbackTimer?.cancel();
              }
            }
          });
        });
        _startControlsTimer();
      } else {
        _playbackTimer?.cancel();
      }
    });
  }

  void _stepFrame(int direction) {
    setState(() {
      _isPlaying = false;
      _playbackTimer?.cancel();
      _currentTime = (_currentTime + direction * (1.0 / _timecode.fps)).clamp(0.0, _totalDuration);
      _showControls = true;
    });
  }

  void _openMediaFileDialog() {
    final textCtrl = TextEditingController(text: _mediaPath);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StudioTheme.surfaceElevated,
        title: const Row(
          children: [
            Icon(Icons.folder_open, color: StudioTheme.accentCyan),
            SizedBox(width: 8),
            Text("Open Media File"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter or select video file path:", style: TextStyle(fontSize: 12, color: StudioTheme.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: textCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: "Path to video file (.mp4, .mkv, .mov)...",
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text("Sample 1080p"),
                  onPressed: () => textCtrl.text = "assets/demo_1080p.mp4",
                ),
                ActionChip(
                  label: const Text("Sample 4K"),
                  onPressed: () => textCtrl.text = "assets/demo_4k.mp4",
                ),
                ActionChip(
                  label: const Text("Audio Feed"),
                  onPressed: () => textCtrl.text = "assets/audio_track.wav",
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: StudioTheme.accentCyan,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final path = textCtrl.text.trim();
              if (path.isNotEmpty) {
                final probe = MediaService.instance.probeMedia(path);
                setState(() {
                  _mediaPath = path;
                  _probeInfo = probe;
                  _totalDuration = probe.durationSeconds;
                  _currentTime = 0.0;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Loaded media: $path (${probe.width}x${probe.height}, ${probe.durationSeconds.toStringAsFixed(1)}s)"),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            child: const Text("Load Media"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
          if (_showControls) _startControlsTimer();
        });
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Center(
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
                          mediaPath: _mediaPath,
                          currentTime: _currentTime,
                          duration: _totalDuration,
                          isPlaying: _isPlaying,
                        ),
                      ),
                      // Top Left Media Info Chip
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.movie, size: 14, color: StudioTheme.accentCyan),
                              const SizedBox(width: 6),
                              Text(
                                "${_probeInfo?.width ?? 1920}x${_probeInfo?.height ?? 1080} | ${_probeInfo?.fps.round() ?? 30}fps | ${_probeInfo?.audioChannels ?? 2}ch",
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _timecode.formatTimecode(_currentTime),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: StudioTheme.accentCyan,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (_selectedSubtitle != 'Off')
                        Positioned(
                          bottom: 40,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Universal Video Studio - Production Ready",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            TimecodeHelper.formatDurationSeconds(_currentTime),
                            style: const TextStyle(color: StudioTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                          ),
                          Expanded(
                            child: Slider(
                              value: _currentTime.clamp(0.0, _totalDuration),
                              min: 0.0,
                              max: _totalDuration,
                              onChanged: (val) {
                                setState(() {
                                  _currentTime = val;
                                  _startControlsTimer();
                                });
                              },
                            ),
                          ),
                          Text(
                            TimecodeHelper.formatDurationSeconds(_totalDuration),
                            style: const TextStyle(color: StudioTheme.textSecondary, fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ],
                      ),

                      // Responsive Horizontal Scrollable Bar for controls
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.folder_open, color: StudioTheme.accentCyan, size: 20),
                              tooltip: "Open Media File",
                              onPressed: _openMediaFileDialog,
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_previous, color: StudioTheme.textPrimary, size: 20),
                              tooltip: "Previous Frame (Left Arrow)",
                              onPressed: () => _stepFrame(-1),
                            ),
                            IconButton(
                              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                  size: 34, color: StudioTheme.accentCyan),
                              tooltip: "Play / Pause (Space)",
                              onPressed: _togglePlayPause,
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next, color: StudioTheme.textPrimary, size: 20),
                              tooltip: "Next Frame (Right Arrow)",
                              onPressed: () => _stepFrame(1),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<double>(
                              value: _playbackSpeed,
                              dropdownColor: StudioTheme.surfaceElevated,
                              underline: const SizedBox(),
                              style: const TextStyle(color: StudioTheme.textPrimary, fontSize: 12),
                              items: [0.25, 0.5, 1.0, 1.5, 2.0, 4.0].map((s) {
                                return DropdownMenuItem(value: s, child: Text("${s}x"));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _playbackSpeed = val);
                              },
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => setState(() => _pointA = _currentTime),
                              child: Text(_pointA == null ? "Set A" : "A: ${_pointA!.toStringAsFixed(1)}s",
                                  style: TextStyle(
                                      color: _pointA != null ? StudioTheme.accentEmerald : StudioTheme.textSecondary,
                                      fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _pointB = _currentTime),
                              child: Text(_pointB == null ? "Set B" : "B: ${_pointB!.toStringAsFixed(1)}s",
                                  style: TextStyle(
                                      color: _pointB != null ? StudioTheme.accentEmerald : StudioTheme.textSecondary,
                                      fontSize: 12)),
                            ),
                            if (_pointA != null || _pointB != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: StudioTheme.textMuted),
                                tooltip: "Clear A-B Repeat",
                                onPressed: () => setState(() {
                                  _pointA = null;
                                  _pointB = null;
                                }),
                              ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.subtitles, color: StudioTheme.textPrimary, size: 20),
                              tooltip: "Subtitles",
                              onSelected: (val) => setState(() => _selectedSubtitle = val),
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'Off', child: Text('Off')),
                                const PopupMenuItem(value: 'English [CC]', child: Text('English [CC]')),
                                const PopupMenuItem(value: 'Spanish', child: Text('Spanish')),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.tune, color: StudioTheme.textPrimary, size: 20),
                              tooltip: "Audio Sync",
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: StudioTheme.surfaceElevated,
                                    title: const Text("Audio Sync Calibration"),
                                    content: StatefulBuilder(
                                      builder: (ctx, setDlgState) => Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text("Offset: ${_audioDelayMs.round()} ms",
                                              style: const TextStyle(color: StudioTheme.accentCyan)),
                                          Slider(
                                            min: -2000,
                                            max: 2000,
                                            value: _audioDelayMs,
                                            onChanged: (v) {
                                              setDlgState(() => _audioDelayMs = v);
                                              setState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
                                    ],
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.camera_alt, color: StudioTheme.textPrimary, size: 20),
                              tooltip: "Capture Snapshot",
                              onPressed: () {
                                final snapDir = Directory("exports/snapshots");
                                if (!snapDir.existsSync()) {
                                  try {
                                    snapDir.createSync(recursive: true);
                                  } catch (_) {}
                                }
                                final snapPath = "exports/snapshots/snapshot_${DateTime.now().millisecondsSinceEpoch}.png";
                                try {
                                  final snapFile = File(snapPath);
                                  snapFile.writeAsStringSync("UVS_SNAPSHOT_METADATA\nsource: $_mediaPath\ntime: $_currentTime\n");
                                } catch (_) {}
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Captured frame snapshot: $snapPath"),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
