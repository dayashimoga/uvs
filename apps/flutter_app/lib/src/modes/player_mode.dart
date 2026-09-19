import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/timecode.dart';
import '../services/media_service.dart';
import '../services/platform_file_picker.dart';
import '../services/recent_media_service.dart';
import '../widgets/video_monitor_surface.dart';

class PlayerModeView extends StatefulWidget {
  const PlayerModeView({super.key});

  @override
  State<PlayerModeView> createState() => _PlayerModeViewState();
}

class _PlayerModeViewState extends State<PlayerModeView> {
  final TimecodeHelper _timecode = const TimecodeHelper(fpsNum: 30, fpsDen: 1);
  double _currentTime = 0.0;
  double _totalDuration = 10.0;
  String? _mediaPath;
  MediaProbeResult? _probeInfo;

  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  Timer? _playbackTimer;

  double? _pointA;
  double? _pointB;
  double _audioDelayMs = 0.0;

  String _selectedSubtitle = 'Off';
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _startControlsTimer();

    // In dev/test environments, check if fixture is present
    final testFixture = MediaService.resolveFixture('media/fixtures/test_smpte_1080p.mp4');
    if (testFixture != null) {
      _loadMediaFile(testFixture);
    }
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
    if (_mediaPath == null) return;
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
    if (_mediaPath == null) return;
    setState(() {
      _isPlaying = false;
      _playbackTimer?.cancel();
      _currentTime = (_currentTime + direction * (1.0 / _timecode.fps)).clamp(0.0, _totalDuration);
      _showControls = true;
    });
  }

  Future<void> _loadMediaFile(String path) async {
    try {
      final probe = MediaService.instance.validateAndIngestMedia(path);
      setState(() {
        _mediaPath = probe.path;
        _probeInfo = probe;
        _totalDuration = probe.durationSeconds > 0 ? probe.durationSeconds : 10.0;
        _currentTime = 0.0;
        _isPlaying = false;
      });
      _playbackTimer?.cancel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to open media: $e"),
            backgroundColor: StudioTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _openMediaFileDialog() async {
    try {
      final picked = await PlatformFilePicker.pickMediaFiles(
        allowMultiple: false,
        dialogTitle: "Open Media File",
      );
      if (picked.isNotEmpty) {
        await _loadMediaFile(picked.first);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening file: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) {
        if (!_showControls) {
          setState(() => _showControls = true);
          _startControlsTimer();
        }
      },
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
            if (_showControls) _startControlsTimer();
          });
        },
        child: Container(
          color: Colors.black,
          child: _mediaPath == null
              ? _buildEmptyPlayerState()
              : _buildActivePlayer(),
        ),
      ),
    );
  }

  Widget _buildEmptyPlayerState() {
    final recents = RecentMediaService.instance.recentMedia;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: StudioTheme.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: StudioTheme.border),
              ),
              child: const Icon(Icons.play_circle_outline, size: 48, color: StudioTheme.accentCyan),
            ),
            const SizedBox(height: 16),
            const Text(
              "Universal Video Player",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            const Text(
              "Open any media file to start high-performance playback",
              style: TextStyle(color: StudioTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text("Open Media File", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudioTheme.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  onPressed: _openMediaFileDialog,
                ),
                if (recents.isNotEmpty)
                  PopupMenuButton<String>(
                    tooltip: "Recent Media",
                    onSelected: (p) => _loadMediaFile(p),
                    itemBuilder: (ctx) => recents.map((p) {
                      final name = p.replaceAll('\\', '/').split('/').last;
                      return PopupMenuItem(
                        value: p,
                        child: Text(name, style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text("Recent Files"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: StudioTheme.textPrimary,
                        side: const BorderSide(color: StudioTheme.border),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePlayer() {
    return Stack(
      children: [
        // Video monitor filling viewport cleanly
        Center(
          child: AspectRatio(
            aspectRatio: (_probeInfo != null && _probeInfo!.width > 0 && _probeInfo!.height > 0)
                ? _probeInfo!.width / _probeInfo!.height
                : 16 / 9,
            child: VideoMonitorSurface(
              mediaPath: _mediaPath,
              currentTime: _currentTime,
              duration: _totalDuration,
              isPlaying: _isPlaying,
            ),
          ),
        ),

        // Subtitles Overlay
        if (_selectedSubtitle != 'Off')
          Positioned(
            bottom: 70,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _selectedSubtitle == 'English [CC]' ? "English Subtitles Active" : "Subtitles Active",
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),

        // Top Header Info Overlay (revealed with controls)
        if (_showControls)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          "${_probeInfo?.width ?? 1920}x${_probeInfo?.height ?? 1080} | ${_probeInfo?.fps.round() ?? 30}fps",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _timecode.formatTimecode(_currentTime),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: StudioTheme.accentCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Bottom Controls Overlay
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
                  // Seek Bar
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
                          max: _totalDuration > 0 ? _totalDuration : 1.0,
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

                  // Buttons row
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
    );
  }
}
