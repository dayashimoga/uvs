import 'package:flutter/material.dart';
import 'src/core/theme.dart';
import 'src/modes/player_mode.dart';
import 'src/modes/multi_view_mode.dart';
import 'src/modes/quick_edit_mode.dart';
import 'src/modes/studio_editor_mode.dart';
import 'src/modes/multicam_mode.dart';
import 'src/modes/recording_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UniversalVideoStudioApp());
}

class UniversalVideoStudioApp extends StatelessWidget {
  const UniversalVideoStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Universal Video Studio',
      debugShowCheckedModeBanner: false,
      theme: StudioTheme.darkTheme,
      home: const MainStudioShell(),
    );
  }
}

class MainStudioShell extends StatefulWidget {
  const MainStudioShell({super.key});

  @override
  State<MainStudioShell> createState() => _MainStudioShellState();
}

class _MainStudioShellState extends State<MainStudioShell> {
  int _currentModeIndex = 0;

  final List<String> _modeTitles = [
    "Player",
    "Multi-View",
    "Quick Edit",
    "Studio Editor",
    "Multicam",
  ];

  final List<IconData> _modeIcons = [
    Icons.play_circle_outline,
    Icons.grid_view,
    Icons.auto_fix_high,
    Icons.movie_creation_outlined,
    Icons.switch_video,
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [StudioTheme.accentCyan, StudioTheme.accentBlue],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.videocam, color: Colors.black, size: 16),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isMobile ? "UVS" : "Universal Video Studio",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: StudioTheme.accentEmerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: StudioTheme.accentEmerald.withOpacity(0.5)),
                ),
                child: const Text(
                  "PROD v0.1.0",
                  style: TextStyle(color: StudioTheme.accentEmerald, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Mode Switcher (for desktop and tablet)
          if (!isMobile)
            Row(
              children: List.generate(_modeTitles.length, (idx) {
                final isSelected = _currentModeIndex == idx;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton.icon(
                    icon: Icon(_modeIcons[idx],
                        size: 16, color: isSelected ? StudioTheme.accentCyan : StudioTheme.textSecondary),
                    label: Text(_modeTitles[idx]),
                    style: TextButton.styleFrom(
                      foregroundColor: isSelected ? StudioTheme.accentCyan : StudioTheme.textSecondary,
                      backgroundColor: isSelected ? StudioTheme.surfaceElevated : Colors.transparent,
                    ),
                    onPressed: () => setState(() => _currentModeIndex = idx),
                  ),
                );
              }),
            ),

          const SizedBox(width: 4),
          // Record Button
          IconButton(
            icon: const Icon(Icons.fiber_manual_record, color: StudioTheme.accentRed, size: 20),
            tooltip: "Record Screen & Camera",
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const RecordingDialog(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildCurrentMode(),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _currentModeIndex,
              onTap: (idx) => setState(() => _currentModeIndex = idx),
              backgroundColor: StudioTheme.surface,
              selectedItemColor: StudioTheme.accentCyan,
              unselectedItemColor: StudioTheme.textSecondary,
              type: BottomNavigationBarType.fixed,
              items: List.generate(_modeTitles.length, (idx) {
                return BottomNavigationBarItem(
                  icon: Icon(_modeIcons[idx]),
                  label: _modeTitles[idx],
                );
              }),
            )
          : Container(
              height: 24,
              color: StudioTheme.surfaceElevated,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Row(
                children: [
                  Text("Ready", style: TextStyle(fontSize: 11, color: StudioTheme.accentEmerald)),
                  SizedBox(width: 16),
                  Text("HW Accel: Active (Intel/Nvidia/VAAPI/Apple)", style: TextStyle(fontSize: 11, color: StudioTheme.textSecondary)),
                  Spacer(),
                  Text("Audio: 48kHz 32-bit Float | FPS: 30.00 | Schema: .uvsp v1",
                      style: TextStyle(fontSize: 11, color: StudioTheme.textMuted)),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentMode() {
    switch (_currentModeIndex) {
      case 0:
        return const PlayerModeView();
      case 1:
        return const MultiViewModeView();
      case 2:
        return const QuickEditModeView();
      case 3:
        return const StudioEditorModeView();
      case 4:
        return const MulticamModeView();
      default:
        return const PlayerModeView();
    }
  }
}
