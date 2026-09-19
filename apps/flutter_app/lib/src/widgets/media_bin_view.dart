import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/timecode.dart';
import '../services/media_service.dart';
import '../services/platform_file_picker.dart';

class MediaBinItem {
  final String id;
  final String path;
  final String name;
  final double duration;
  final int width;
  final int height;
  final double fps;
  final int channels;
  final String? thumbnailPath;

  MediaBinItem({
    required this.id,
    required this.path,
    required this.name,
    required this.duration,
    required this.width,
    required this.height,
    required this.fps,
    required this.channels,
    this.thumbnailPath,
  });

  bool get isVideo => width > 0 && height > 0;
  bool get isAudioOnly => !isVideo && channels > 0;
  bool get exists => File(path).existsSync();
}

class MediaBinView extends StatefulWidget {
  final List<MediaBinItem> items;
  final ValueChanged<MediaBinItem>? onSelectPreview;
  final ValueChanged<MediaBinItem>? onAddToTimeline;
  final ValueChanged<List<MediaBinItem>>? onItemsChanged;

  const MediaBinView({
    super.key,
    required this.items,
    this.onSelectPreview,
    this.onAddToTimeline,
    this.onItemsChanged,
  });

  @override
  State<MediaBinView> createState() => _MediaBinViewState();
}

class _MediaBinViewState extends State<MediaBinView> {
  bool _isGridView = true;
  String _searchQuery = "";
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _importFiles() async {
    try {
      final probes = await MediaService.instance.pickAndIngestMedia(allowMultiple: true);
      if (probes.isNotEmpty) {
        final newItems = List<MediaBinItem>.from(widget.items);
        for (final probe in probes) {
          if (!newItems.any((it) => it.path == probe.path)) {
            newItems.add(MediaBinItem(
              id: 'bin-${DateTime.now().millisecondsSinceEpoch}-${newItems.length}',
              path: probe.path,
              name: probe.fileName,
              duration: probe.durationSeconds,
              width: probe.width,
              height: probe.height,
              fps: probe.fps,
              channels: probe.audioChannels,
              thumbnailPath: probe.thumbnailPath,
            ));
          }
        }
        widget.onItemsChanged?.call(newItems);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import failed: $e")),
        );
      }
    }
  }

  Future<void> _importFolder() async {
    try {
      final folderPath = await PlatformFilePicker.pickFolder();
      if (folderPath != null && Directory(folderPath).existsSync()) {
        final dir = Directory(folderPath);
        final entities = dir.listSync(recursive: false);
        final newItems = List<MediaBinItem>.from(widget.items);
        int added = 0;

        for (final entity in entities) {
          if (entity is File) {
            final ext = entity.path.split('.').last.toLowerCase();
            if (PlatformFilePicker.supportedMediaExtensions.contains(ext)) {
              try {
                final probe = MediaService.instance.validateAndIngestMedia(entity.path);
                if (!newItems.any((it) => it.path == probe.path)) {
                  newItems.add(MediaBinItem(
                    id: 'bin-${DateTime.now().millisecondsSinceEpoch}-${newItems.length}',
                    path: probe.path,
                    name: probe.fileName,
                    duration: probe.durationSeconds,
                    width: probe.width,
                    height: probe.height,
                    fps: probe.fps,
                    channels: probe.audioChannels,
                    thumbnailPath: probe.thumbnailPath,
                  ));
                  added++;
                }
              } catch (_) {}
            }
          }
        }

        if (added > 0) {
          widget.onItemsChanged?.call(newItems);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Imported $added media files from folder")),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Folder import failed: $e")),
        );
      }
    }
  }

  void _removeItem(MediaBinItem item) {
    final newItems = List<MediaBinItem>.from(widget.items)..remove(item);
    widget.onItemsChanged?.call(newItems);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((it) {
      if (_searchQuery.isEmpty) return true;
      return it.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      color: StudioTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: StudioTheme.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_special_outlined, size: 14, color: StudioTheme.accentCyan),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "Media (${widget.items.length})",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                  tooltip: "Import Media Files",
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: _importFiles,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.drive_folder_upload_outlined, size: 16),
                  tooltip: "Import Folder",
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: _importFolder,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, size: 16),
                  tooltip: _isGridView ? "Switch to List View" : "Switch to Grid View",
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ),
          ),

          // Search bar
          if (widget.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SizedBox(
                height: 28,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: "Filter media...",
                    prefixIcon: const Icon(Icons.search, size: 14),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  style: const TextStyle(fontSize: 11),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),

          // Content Area
          Expanded(
            child: widget.items.isEmpty
                ? _buildEmptyState()
                : _isGridView
                    ? _buildGrid(filtered)
                    : _buildList(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StudioTheme.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: StudioTheme.border),
              ),
              child: const Icon(Icons.video_library_outlined, size: 28, color: StudioTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            const Text(
              "No Media Ingested",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              "Import native videos or audio to begin editing",
              style: TextStyle(color: StudioTheme.textSecondary, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open, size: 14),
              label: const Text("Import Media", style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: StudioTheme.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: _importFiles,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<MediaBinItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, idx) => _buildGridCard(items[idx]),
    );
  }

  Widget _buildGridCard(MediaBinItem item) {
    final hasThumb = item.thumbnailPath != null && File(item.thumbnailPath!).existsSync();

    return InkWell(
      onTap: () => widget.onSelectPreview?.call(item),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: StudioTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: StudioTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasThumb)
                    Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                  else
                    Container(
                      color: Colors.black26,
                      child: Icon(
                        item.isVideo ? Icons.movie_outlined : Icons.audiotrack_outlined,
                        size: 28,
                        color: StudioTheme.accentCyan.withOpacity(0.7),
                      ),
                    ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        TimecodeHelper.formatDurationSeconds(item.duration),
                        style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${item.width}x${item.height} • ${item.fps.round()}fps",
                          style: const TextStyle(fontSize: 9, color: StudioTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 14, color: StudioTheme.textSecondary),
                    onSelected: (val) {
                      if (val == 'timeline') {
                        widget.onAddToTimeline?.call(item);
                      } else if (val == 'remove') {
                        _removeItem(item);
                      }
                    },
                    itemBuilder: (c) => [
                      const PopupMenuItem(value: 'timeline', child: Text("Add to Timeline", style: TextStyle(fontSize: 12))),
                      const PopupMenuItem(value: 'remove', child: Text("Remove from Bin", style: TextStyle(fontSize: 12, color: StudioTheme.accentRed))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<MediaBinItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(6),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: StudioTheme.border),
      itemBuilder: (ctx, idx) {
        final item = items[idx];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            leading: Container(
              width: 48,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(3),
              ),
              clipBehavior: Clip.antiAlias,
              child: (item.thumbnailPath != null && File(item.thumbnailPath!).existsSync())
                  ? Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                  : Icon(item.isVideo ? Icons.movie_outlined : Icons.audiotrack, size: 16, color: StudioTheme.accentCyan),
            ),
            title: Text(item.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text("${item.width}x${item.height} | ${TimecodeHelper.formatDurationSeconds(item.duration)}", style: const TextStyle(fontSize: 10, color: StudioTheme.textSecondary)),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 16, color: StudioTheme.accentCyan),
              tooltip: "Add to Timeline",
              onPressed: () => widget.onAddToTimeline?.call(item),
            ),
            onTap: () => widget.onSelectPreview?.call(item),
          ),
        );
      },
    );
  }
}
