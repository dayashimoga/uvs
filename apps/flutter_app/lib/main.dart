import 'package:flutter/material.dart';
import 'src/core/theme.dart';
import 'src/modes/player_mode.dart';
import 'src/modes/multi_view_mode.dart';
import 'src/modes/quick_edit_mode.dart';
import 'src/modes/studio_editor_mode.dart';
import 'src/modes/multicam_mode.dart';
import 'src/modes/recording_dialog.dart';

import 'src/services/project_service.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ProjectService.enableAutosave = true;
  runApp(const UniversalVideoStudioApp());
}

class UniversalVideoStudioApp extends StatelessWidget {
  const UniversalVideoStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Universal Video Studio',
          debugShowCheckedModeBanner: false,
          theme: StudioTheme.lightTheme,
          darkTheme: StudioTheme.darkTheme,
          themeMode: mode,
          home: const MainStudioShell(),
        );
      },
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
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    Widget bodyContent;
    if (isTablet) {
      bodyContent = Row(
        children: [
          NavigationRail(
            selectedIndex: _currentModeIndex,
            onDestinationSelected: (idx) => setState(() => _currentModeIndex = idx),
            backgroundColor: StudioTheme.surface,
            selectedIconTheme: const IconThemeData(color: StudioTheme.accentCyan),
            unselectedIconTheme: const IconThemeData(color: StudioTheme.textSecondary),
            labelType: NavigationRailLabelType.all,
            destinations: List.generate(_modeTitles.length, (idx) {
              return NavigationRailDestination(
                icon: Icon(_modeIcons[idx]),
                label: Text(_modeTitles[idx], style: const TextStyle(fontSize: 10)),
              );
            }),
          ),
          const VerticalDivider(width: 1, color: StudioTheme.border),
          Expanded(child: _buildCurrentMode()),
        ],
      );
    } else {
      bodyContent = _buildCurrentMode();
    }

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
          ],
        ),
        actions: [
          // Mode Switcher for desktop
          if (isDesktop)
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
          // Theme Toggle Button
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (ctx, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
                tooltip: isDark ? "Switch to Light Mode" : "Switch to Dark Mode",
                onPressed: () {
                  themeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                },
              );
            },
          ),
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
      body: bodyContent,
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text("Ready", style: TextStyle(fontSize: 11, color: StudioTheme.accentEmerald)),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Text(
                      "HW Accel: Active",
                      style: TextStyle(fontSize: 11, color: StudioTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDesktop) ...[
                    const Spacer(),
                    const Text(
                      "Audio: 48kHz Float | FPS: 30.00 | .uvsp v1",
                      style: TextStyle(fontSize: 11, color: StudioTheme.textMuted),
                    ),
                  ],
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
