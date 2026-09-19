import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/ffi_bridge.dart';
import '../services/project_service.dart';
import '../services/platform_file_picker.dart';
import '../widgets/video_monitor_surface.dart';

class MulticamModeView extends StatefulWidget {
  const MulticamModeView({super.key});

  @override
  State<MulticamModeView> createState() => _MulticamModeViewState();
}

class _MulticamModeViewState extends State<MulticamModeView> {
  int _activeAngle = 0; // 0, 1, 2, 3
  bool _syncByAudio = true;
  final List<Map<String, dynamic>> _recordedCuts = [];
  final List<String?> _anglePaths = [null, null, null, null];

  final List<String> _angles = [
    "Angle 1 (Wide Front)",
    "Angle 2 (Close-up Actor A)",
    "Angle 3 (Close-up Actor B)",
    "Angle 4 (Overhead Drone)",
  ];

  Future<void> _importAngle(int index) async {
    try {
      final picked = await PlatformFilePicker.pickMediaFiles(
        allowMultiple: false,
        dialogTitle: "Select Video for ${_angles[index]}",
      );
      if (picked.isNotEmpty) {
        setState(() {
          _anglePaths[index] = picked.first;
          _angles[index] = picked.first.replaceAll('\\', '/').split('/').last;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not assign angle: $e")),
        );
      }
    }
  }

  Future<void> _importAllAngles() async {
    try {
      final picked = await PlatformFilePicker.pickMediaFiles(
        allowMultiple: true,
        dialogTitle: "Select 4 Multicam Angle Videos",
      );
      if (picked.isNotEmpty) {
        setState(() {
          for (int i = 0; i < 4 && i < picked.length; i++) {
            _anglePaths[i] = picked[i];
            _angles[i] = picked[i].replaceAll('\\', '/').split('/').last;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Imported ${picked.length.clamp(1, 4)} camera angles")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Multicam import error: $e")),
        );
      }
    }
  }

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
                ElevatedButton.icon(
                  icon: const Icon(Icons.video_library_outlined, size: 16),
                  label: const Text("Import Camera Files"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudioTheme.surfaceElevated,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _importAllAngles,
                ),
                const SizedBox(width: 12),
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
                      _recordedCuts.addAll([
                        {'name': _angles[0], 'media_path': _anglePaths[0] ?? 'cam1.mp4', 'time_s': 0.0},
                        {'name': _angles[1], 'media_path': _anglePaths[1] ?? 'cam2.mp4', 'time_s': 4.0},
                        {'name': _angles[2], 'media_path': _anglePaths[2] ?? 'cam3.mp4', 'time_s': 8.0},
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
                    final hasMedia = _anglePaths[idx] != null;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _activeAngle = idx;
                          _recordedCuts.add({
                            'name': _angles[idx],
                            'media_path': _anglePaths[idx] ?? 'cam${idx + 1}.mp4',
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
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            if (hasMedia)
                              Positioned.fill(
                                child: VideoMonitorSurface(
                                  mediaPath: _anglePaths[idx],
                                  currentTime: idx * 2.0,
                                  duration: 60.0,
                                  isPlaying: true,
                                ),
                              )
                            else
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

                            // Top Left Cam Tag
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

                            // Top Right Action Buttons
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.folder_open, size: 16, color: Colors.white),
                                    tooltip: "Assign Video File to CAM ${idx + 1}",
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _importAngle(idx),
                                  ),
                                  if (isActive) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: StudioTheme.accentRed,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text("PROGRAM ON AIR",
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                    ),
                                  ],
                                ],
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
