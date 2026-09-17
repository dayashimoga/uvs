import 'package:flutter/material.dart';
import '../core/theme.dart';

class MulticamModeView extends StatefulWidget {
  const MulticamModeView({super.key});

  @override
  State<MulticamModeView> createState() => _MulticamModeViewState();
}

class _MulticamModeViewState extends State<MulticamModeView> {
  int _activeAngle = 0; // 0, 1, 2, 3
  bool _syncByAudio = true;

  final List<String> _angles = [
    "Angle 1 (Wide Front)",
    "Angle 2 (Close-up Actor A)",
    "Angle 3 (Close-up Actor B)",
    "Angle 4 (Overhead Drone)",
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Multicam Toolbar
        Container(
          height: 48,
          color: StudioTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.switch_video, color: StudioTheme.accentCyan, size: 20),
              const SizedBox(width: 8),
              const Text("Multicam Synchronized Switching", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              ChoiceChip(
                label: const Text("Audio Correlation Sync"),
                selected: _syncByAudio,
                onSelected: (s) => setState(() => _syncByAudio = s),
                selectedColor: StudioTheme.accentCyan.withOpacity(0.2),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.sync, size: 16),
                label: const Text("Auto-Sync Angles"),
                style: ElevatedButton.styleFrom(backgroundColor: StudioTheme.accentBlue, foregroundColor: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Auto-aligned 4 angles using audio waveform cross-correlation (0 frame drift)")),
                  );
                },
              ),
            ],
          ),
        ),

        // Quad Angle Grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 16 / 9,
              ),
              itemCount: 4,
              itemBuilder: (ctx, idx) {
                final isActive = _activeAngle == idx;
                return GestureDetector(
                  onTap: () {
                    setState(() => _activeAngle = idx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Switched cut to ${_angles[idx]} at current playhead"),
                        duration: const Duration(milliseconds: 800),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: StudioTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive ? StudioTheme.accentEmerald : StudioTheme.border,
                        width: isActive ? 3 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam, size: 48, color: isActive ? StudioTheme.accentEmerald : StudioTheme.textMuted),
                              const SizedBox(height: 8),
                              Text(_angles[idx],
                                  style: TextStyle(
                                    color: isActive ? StudioTheme.accentEmerald : StudioTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive ? StudioTheme.accentEmerald : Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "CAM ${idx + 1}",
                              style: TextStyle(
                                color: isActive ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        if (isActive)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: StudioTheme.accentRed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text("PROGRAM ON AIR",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
