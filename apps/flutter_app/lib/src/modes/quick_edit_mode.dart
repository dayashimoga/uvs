import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/timecode.dart';
import '../services/media_service.dart';
import '../services/platform_file_picker.dart';
import '../services/render_service.dart';
import '../widgets/video_monitor_surface.dart';

class QuickEditModeView extends StatefulWidget {
  const QuickEditModeView({super.key});

  @override
  State<QuickEditModeView> createState() => _QuickEditModeViewState();
}

class _QuickEditModeViewState extends State<QuickEditModeView> {
  String? _mediaPath;
  MediaProbeResult? _probeInfo;
  double _trimStart = 0.5;
  double _trimEnd = 3.5;
  double _duration = 4.0;

  int _rotation = 0; // 0, 90, 180, 270
  String _aspectRatio = '16:9'; // '16:9', '9:16', '1:1', '4:3'
  double _speed = 1.0;
  double _volume = 1.0;
  String _selectedFilter = 'Normal';
  final TextEditingController _subtitleCtrl = TextEditingController(text: "Quick Title Overlay");

  final List<String> _filterPresets = [
    'Normal',
    'Cinematic Warm',
    'Cool Mist',
    'B&W Contrast',
    'Vibrant Pop',
  ];

  @override
  void initState() {
    super.initState();
    final testFixture = MediaService.resolveFixture('media/fixtures/test_smpte_1080p.mp4');
    if (testFixture != null) {
      _loadMedia(testFixture);
    }
  }

  void _loadMedia(String path) {
    try {
      final probe = MediaService.instance.validateAndIngestMedia(path);
      setState(() {
        _mediaPath = probe.path;
        _probeInfo = probe;
        _duration = probe.durationSeconds > 0 ? probe.durationSeconds : 4.0;
        _trimStart = 0.0;
        _trimEnd = _duration;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open media: $e")),
        );
      }
    }
  }

  Future<void> _openMediaFile() async {
    try {
      final picked = await PlatformFilePicker.pickMediaFiles(
        allowMultiple: false,
        dialogTitle: "Open Media for Quick Edit",
      );
      if (picked.isNotEmpty) {
        _loadMedia(picked.first);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening file: $e")),
        );
      }
    }
  }

  Color _getFilterTint() {
    switch (_selectedFilter) {
      case 'Cinematic Warm': return Colors.amber.withOpacity(0.15);
      case 'Cool Mist': return Colors.cyan.withOpacity(0.15);
      case 'B&W Contrast': return Colors.grey.withOpacity(0.4);
      case 'Vibrant Pop': return Colors.deepOrange.withOpacity(0.1);
      default: return Colors.transparent;
    }
  }

  @override
  void dispose() {
    _subtitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Quick Edit Toolbar
        Container(
          height: 44,
          color: StudioTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.auto_fix_high, size: 18, color: StudioTheme.accentCyan),
                const SizedBox(width: 8),
                const Text("Quick Edit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (_mediaPath != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: StudioTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${_mediaPath!.replaceAll('\\', '/').split('/').last} (${_probeInfo?.resolutionString ?? '1080p'})",
                      style: const TextStyle(fontSize: 11, color: StudioTheme.accentCyan),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text("Open Media"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudioTheme.surfaceElevated,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _openMediaFile,
                ),
              ],
            ),
          ),
        ),

        // Body
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 700;
              final preview = _buildPreview();
              final inspector = _buildInspector();

              if (isCompact) {
                return Column(
                  children: [
                    Expanded(flex: 5, child: preview),
                    Expanded(flex: 5, child: inspector),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 6, child: preview),
                  SizedBox(width: 320, child: inspector),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _aspectRatio == '9:16' ? 9 / 16 : _aspectRatio == '1:1' ? 1 : 16 / 9,
              child: RotatedBox(
                quarterTurns: _rotation ~/ 90,
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
                          currentTime: _trimStart,
                          duration: _duration,
                        ),
                      ),
                      // Filter Tint Overlay
                      Container(color: _getFilterTint()),
                      // Text Overlay
                      if (_subtitleCtrl.text.isNotEmpty)
                        Positioned(
                          bottom: 30,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            color: Colors.black.withOpacity(0.6),
                            child: Text(
                              _subtitleCtrl.text,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Bottom Trim Range Slider
        Container(
          color: StudioTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Trim In: ${TimecodeHelper.formatDurationSeconds(_trimStart)}",
                        style: const TextStyle(color: StudioTheme.accentCyan, fontSize: 12)),
                    const SizedBox(width: 16),
                    Text("Duration: ${TimecodeHelper.formatDurationSeconds(_trimEnd - _trimStart)}",
                        style: const TextStyle(color: StudioTheme.textSecondary, fontSize: 12)),
                    const SizedBox(width: 16),
                    Text("Trim Out: ${TimecodeHelper.formatDurationSeconds(_trimEnd)}",
                        style: const TextStyle(color: StudioTheme.accentCyan, fontSize: 12)),
                  ],
                ),
              ),
              RangeSlider(
                values: RangeValues(_trimStart.clamp(0.0, _duration), _trimEnd.clamp(0.0, _duration)),
                min: 0.0,
                max: _duration > 0 ? _duration : 1.0,
                activeColor: StudioTheme.accentCyan,
                inactiveColor: StudioTheme.surfaceHighlight,
                onChanged: (vals) {
                  setState(() {
                    _trimStart = vals.start;
                    _trimEnd = vals.end;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInspector() {
    return Container(
      color: StudioTheme.surface,
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text("Quick Adjustments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(color: StudioTheme.border, height: 24),

          // Aspect Ratio
          const Text("Aspect Ratio", style: TextStyle(color: StudioTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: ['16:9', '9:16', '1:1', '4:3'].map((ratio) {
              return ChoiceChip(
                label: Text(ratio),
                selected: _aspectRatio == ratio,
                onSelected: (sel) {
                  if (sel) setState(() => _aspectRatio = ratio);
                },
                selectedColor: StudioTheme.accentCyan.withOpacity(0.2),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Rotation
          const Text("Rotate", style: TextStyle(color: StudioTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.rotate_90_degrees_cw, size: 16),
                label: Text("$_rotation°"),
                onPressed: () {
                  setState(() => _rotation = (_rotation + 90) % 360);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Speed
          Text("Playback Speed: ${_speed.toStringAsFixed(1)}x", style: const TextStyle(color: StudioTheme.textSecondary, fontSize: 12)),
          Slider(
            min: 0.5,
            max: 2.0,
            divisions: 6,
            value: _speed,
            onChanged: (v) => setState(() => _speed = v),
          ),
          const SizedBox(height: 8),

          // Audio Volume
          Text("Audio Level: ${(_volume * 100).round()}%", style: const TextStyle(color: StudioTheme.textSecondary, fontSize: 12)),
          Slider(
            min: 0.0,
            max: 2.0,
            value: _volume,
            onChanged: (v) => setState(() => _volume = v),
          ),
          const SizedBox(height: 8),

          // Color Preset Filter
          const Text("Color Filter Look", style: TextStyle(color: StudioTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButton<String>(
            isExpanded: true,
            value: _selectedFilter,
            dropdownColor: StudioTheme.surfaceElevated,
            items: _filterPresets.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedFilter = v);
            },
          ),
          const SizedBox(height: 16),

          // Subtitle Overlay
          const Text("Text Overlay", style: TextStyle(color: StudioTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _subtitleCtrl,
            decoration: const InputDecoration(
              hintText: "Enter title or caption...",
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),

          // Immediate Export Button
          ElevatedButton.icon(
            icon: const Icon(Icons.rocket_launch, size: 18),
            label: const Text("Export Quick Video"),
            style: ElevatedButton.styleFrom(
              backgroundColor: StudioTheme.accentEmerald,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              final inMedia = _mediaPath ?? 'media/fixtures/test_smpte_1080p.mp4';
              final outPath = "exports/quick_edit_${DateTime.now().millisecondsSinceEpoch}.mp4";
              RenderService.instance.queueRender(
                name: "Quick Edit ($_aspectRatio, $_selectedFilter)",
                outputPath: outPath,
                project: {
                  'render_settings': {
                    'output_format': 'mp4',
                    'video_codec': 'h264',
                    'audio_codec': 'aac',
                    'width': _aspectRatio == '9:16' ? 1080 : (_aspectRatio == '1:1' ? 1080 : 1920),
                    'height': _aspectRatio == '9:16' ? 1920 : (_aspectRatio == '1:1' ? 1080 : 1080),
                    'fps_num': 30,
                    'fps_den': 1,
                    'video_bitrate_kbps': 6000,
                    'audio_bitrate_kbps': 192,
                  }
                },
                inputPath: inMedia,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Rendering Quick Edit ($outPath, ${TimecodeHelper.formatDurationSeconds(_trimEnd - _trimStart)}s, $_aspectRatio)"),
                  backgroundColor: StudioTheme.surfaceElevated,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
