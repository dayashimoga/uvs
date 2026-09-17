import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/timecode.dart';

class QuickEditModeView extends StatefulWidget {
  const QuickEditModeView({super.key});

  @override
  State<QuickEditModeView> createState() => _QuickEditModeViewState();
}

class _QuickEditModeViewState extends State<QuickEditModeView> {
  double _trimStart = 0.5;
  double _trimEnd = 3.5;
  final double _duration = 4.0;

  int _rotation = 0; // 0, 90, 180, 270
  String _aspectRatio = '16:9'; // '16:9', '9:16', '1:1', '4:3'
  double _speed = 1.0;
  String _selectedFilter = 'Normal';
  final TextEditingController _subtitleCtrl = TextEditingController(text: "Quick Title Overlay");

  final List<String> _filterPresets = [
    'Normal',
    'Cinematic Warm',
    'Cool Mist',
    'B&W Contrast',
    'Vibrant Pop',
  ];

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
    return Row(
      children: [
        // Left: Quick Preview
        Expanded(
          flex: 6,
          child: Column(
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
                            // Video Canvas
                            Row(
                              children: [
                                Expanded(child: Container(color: const Color(0xFFC0C0C0))),
                                Expanded(child: Container(color: const Color(0xFFC0C000))),
                                Expanded(child: Container(color: const Color(0xFF00C0C0))),
                                Expanded(child: Container(color: const Color(0xFF00C000))),
                                Expanded(child: Container(color: const Color(0xFFC000C0))),
                              ],
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Trim In: ${TimecodeHelper.formatDurationSeconds(_trimStart)}",
                            style: const TextStyle(color: StudioTheme.accentCyan, fontSize: 12)),
                        Text("Duration: ${TimecodeHelper.formatDurationSeconds(_trimEnd - _trimStart)}",
                            style: const TextStyle(color: StudioTheme.textSecondary, fontSize: 12)),
                        Text("Trim Out: ${TimecodeHelper.formatDurationSeconds(_trimEnd)}",
                            style: const TextStyle(color: StudioTheme.accentCyan, fontSize: 12)),
                      ],
                    ),
                    RangeSlider(
                      values: RangeValues(_trimStart, _trimEnd),
                      min: 0.0,
                      max: _duration,
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
          ),
        ),

        // Right: Quick Tools Inspector
        Container(
          width: 320,
          color: StudioTheme.surface,
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const Text("Quick Adjustments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(color: StudioTheme.border, height: 24),

              // Aspect Ratio (for TikTok/Shorts/Reels)
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Rendering Quick Edit ($_aspectRatio, $_selectedFilter, ${TimecodeHelper.formatDurationSeconds(_trimEnd - _trimStart)}s)..."),
                      backgroundColor: StudioTheme.surfaceElevated,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
