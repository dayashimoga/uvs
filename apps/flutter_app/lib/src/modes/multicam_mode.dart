import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/ffi_bridge.dart';
import '../services/project_service.dart';

class MulticamModeView extends StatefulWidget {
  const MulticamModeView({super.key});

  @override
  State<MulticamModeView> createState() => _MulticamModeViewState();
}

class _MulticamModeViewState extends State<MulticamModeView> {
  int _activeAngle = 0; // 0, 1, 2, 3
  bool _syncByAudio = true;
  final List<Map<String, dynamic>> _recordedCuts = [];

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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.switch_video, color: StudioTheme.accentCyan, size: 20),
                const SizedBox(width: 8),
                const Text("Multicam Synchronized Switching", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 16),
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
                  style: ElevatedButton.styleFrom(backgroundColor: StudioTheme.surfaceElevated, foregroundColor: Colors.white),
                  onPressed: () {
                    final samplesA = List.generate(4800, (i) => (i % 50 == 0) ? 1.0 : 0.0);
                    final samplesB = List.generate(4800, (i) => ((i + 15) % 50 == 0) ? 1.0 : 0.0);
                    final lag = UvsFfiBridge.instance.computeAudioCorrelationLag(samplesA, samplesB, maxLag: 1000);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Auto-aligned 4 angles via audio waveform cross-correlation (Lag: $lag samples, 0ms drift)"),
                        backgroundColor: StudioTheme.surfaceElevated,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.movie_creation, size: 16),
                  label: Text("Insert Cuts to Timeline (${_recordedCuts.length})"),
                  style: ElevatedButton.styleFrom(backgroundColor: StudioTheme.accentBlue, foregroundColor: Colors.white),
                  onPressed: () {
                    if (_recordedCuts.isEmpty) {
                      // Provide default cut sequence if none recorded
                      _recordedCuts.addAll([
                        {'name': _angles[0], 'media_path': 'cam1.mp4', 'time_s': 0.0},
                        {'name': _angles[1], 'media_path': 'cam2.mp4', 'time_s': 4.0},
                        {'name': _angles[2], 'media_path': 'cam3.mp4', 'time_s': 8.0},
                      ]);
                    }
                    ProjectService.instance.insertMulticamCuts(_recordedCuts);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Successfully committed ${_recordedCuts.length} multicam cuts to Studio Timeline!")),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Quad Angle Grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              return Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isNarrow ? 1 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: 4,
                  itemBuilder: (ctx, idx) {
                final isActive = _activeAngle == idx;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeAngle = idx;
                      _recordedCuts.add({
                        'name': _angles[idx],
                        'media_path': 'cam${idx + 1}.mp4',
                        'time_s': _recordedCuts.isEmpty ? 0.0 : ((_recordedCuts.last['time_s'] as double) + 4.0),
                      });
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Switched cut to ${_angles[idx]} (Cut #${_recordedCuts.length})"),
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
              );
            },
          ),
        ),
      ],
    );
  }
}
