import 'package:flutter/material.dart';
import '../core/theme.dart';

class TileFeed {
  final int id;
  final String title;
  bool isPlaying;
  bool isMuted;
  double volume;
  double progress;

  TileFeed({
    required this.id,
    required this.title,
    this.isPlaying = true,
    this.isMuted = false,
    this.volume = 0.8,
    this.progress = 0.0,
  });
}

class MultiViewModeView extends StatefulWidget {
  const MultiViewModeView({super.key});

  @override
  State<MultiViewModeView> createState() => _MultiViewModeViewState();
}

class _MultiViewModeViewState extends State<MultiViewModeView> {
  String _selectedLayout = '2x2'; // '1x1', '1x2', '2x1', '2x2', '1+3', '3x3'
  bool _masterSyncEnabled = false;

  final List<TileFeed> _feeds = [
    TileFeed(id: 1, title: "Feed 1 - Front Main Cam", isMuted: false),
    TileFeed(id: 2, title: "Feed 2 - Side Angle A", isMuted: true),
    TileFeed(id: 3, title: "Feed 3 - Side Angle B", isMuted: true),
    TileFeed(id: 4, title: "Feed 4 - Drone Aerial", isMuted: false),
    TileFeed(id: 5, title: "Feed 5 - Stage Overhead", isMuted: true),
    TileFeed(id: 6, title: "Feed 6 - Backup Feed", isMuted: true),
  ];

  int get _displayedTileCount {
    switch (_selectedLayout) {
      case '1x1': return 1;
      case '1x2': return 2;
      case '2x1': return 2;
      case '2x2': return 4;
      case '1+3': return 4;
      case '3x3': return 6;
      default: return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Toolbar
        Container(
          height: 48,
          color: StudioTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.grid_view, color: StudioTheme.accentCyan, size: 20),
              const SizedBox(width: 8),
              const Text("Multi-View Monitoring", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              // Layout Selector
              DropdownButton<String>(
                value: _selectedLayout,
                dropdownColor: StudioTheme.surfaceElevated,
                underline: const SizedBox(),
                style: const TextStyle(color: StudioTheme.textPrimary, fontSize: 13),
                items: ['1x1', '1x2', '2x1', '2x2', '1+3', '3x3'].map((l) {
                  return DropdownMenuItem(value: l, child: Text("Layout $l"));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLayout = val);
                },
              ),
              const SizedBox(width: 16),
              // Master Sync
              FilterChip(
                label: const Text("Master Sync"),
                selected: _masterSyncEnabled,
                onSelected: (val) {
                  setState(() => _masterSyncEnabled = val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_masterSyncEnabled ? "Master Sync Enabled" : "Master Sync Disabled")),
                  );
                },
                selectedColor: StudioTheme.accentCyan.withOpacity(0.2),
                checkmarkColor: StudioTheme.accentCyan,
              ),
              const SizedBox(width: 16),
              // Send to Studio
              ElevatedButton.icon(
                icon: const Icon(Icons.movie_edit, size: 16),
                label: const Text("Send to Multicam"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StudioTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("All feeds imported to Studio Multicam Timeline")),
                  );
                },
              ),
            ],
          ),
        ),

        // Grid Display
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildGrid(),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    int count = _displayedTileCount;
    int crossAxisCount = _selectedLayout == '1x1'
        ? 1
        : _selectedLayout == '1x2'
            ? 2
            : _selectedLayout == '3x3'
                ? 3
                : 2;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 9,
      ),
      itemCount: count,
      itemBuilder: (ctx, idx) {
        final feed = _feeds[idx % _feeds.length];
        return _buildFeedTile(feed);
      },
    );
  }

  Widget _buildFeedTile(TileFeed feed) {
    return Container(
      decoration: BoxDecoration(
        color: StudioTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: StudioTheme.border),
      ),
      child: Stack(
        children: [
          // Video background simulation
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam, size: 40, color: StudioTheme.textMuted.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text(feed.title, style: const TextStyle(color: StudioTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),

          // Top Badge: Title and Live Indicator
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(feed.title, style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: StudioTheme.accentEmerald,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text("LIVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ],
            ),
          ),

          // Bottom Tile Controls HUD
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  // Play/Pause
                  GestureDetector(
                    onTap: () => setState(() => feed.isPlaying = !feed.isPlaying),
                    child: Icon(feed.isPlaying ? Icons.pause : Icons.play_arrow, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  // Mute / Unmute Matrix
                  GestureDetector(
                    onTap: () => setState(() => feed.isMuted = !feed.isMuted),
                    child: Icon(
                      feed.isMuted ? Icons.volume_off : Icons.volume_up,
                      size: 18,
                      color: feed.isMuted ? StudioTheme.textMuted : StudioTheme.accentCyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Independent Volume Slider
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      ),
                      child: Slider(
                        value: feed.isMuted ? 0.0 : feed.volume,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (v) {
                          setState(() {
                            feed.volume = v;
                            feed.isMuted = false;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
