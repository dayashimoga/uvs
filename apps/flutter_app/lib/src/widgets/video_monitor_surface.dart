import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/media_service.dart';
import '../services/platform_file_picker.dart';

class VideoMonitorSurface extends StatefulWidget {
  final String? mediaPath;
  final double currentTime;
  final double duration;
  final bool isPlaying;
  final Widget? overlay;
  final BoxFit fit;
  final ValueChanged<String>? onRelink;

  const VideoMonitorSurface({
    super.key,
    this.mediaPath,
    required this.currentTime,
    required this.duration,
    this.isPlaying = false,
    this.overlay,
    this.fit = BoxFit.contain,
    this.onRelink,
  });

  @override
  State<VideoMonitorSurface> createState() => _VideoMonitorSurfaceState();
}

class _VideoMonitorSurfaceState extends State<VideoMonitorSurface> {
  String? _framePath;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _resolveAndExtractFrame();
  }

  @override
  void didUpdateWidget(covariant VideoMonitorSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaPath != widget.mediaPath ||
        (oldWidget.currentTime - widget.currentTime).abs() > 0.1 ||
        oldWidget.isPlaying != widget.isPlaying) {
      _resolveAndExtractFrame();
    }
  }

  void _resolveAndExtractFrame() {
    _isOffline = false;
    _framePath = null;

    final path = widget.mediaPath;
    if (path == null || path.isEmpty) {
      // Clean idle monitor - no media assigned
      return;
    }

    if (File(path).existsSync()) {
      if (path.endsWith('.png') || path.endsWith('.jpg')) {
        _framePath = path;
      } else {
        try {
          final extracted = MediaService.instance.extractFrame(path, widget.currentTime);
          if (extracted.isNotEmpty && File(extracted).existsSync()) {
            _framePath = extracted;
          }
        } catch (_) {}
      }
    } else {
      // Media path was explicitly specified but is missing from disk!
      _isOffline = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget videoContent;

    if (_isOffline) {
      videoContent = _buildMediaOfflineView();
    } else if (_framePath != null && File(_framePath!).existsSync()) {
      videoContent = Image.file(
        File(_framePath!),
        fit: widget.fit,
        errorBuilder: (ctx, err, stack) => _buildSyntheticRaster(),
      );
    } else {
      videoContent = _buildSyntheticRaster();
    }

    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: videoContent),
            if (widget.overlay != null) widget.overlay!,
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOfflineView() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E0A0A),
        border: Border.all(color: StudioTheme.accentRed, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                size: 36,
                color: StudioTheme.accentRed,
              ),
              const SizedBox(height: 6),
              const Text(
                "MEDIA OFFLINE",
                style: TextStyle(
                  color: StudioTheme.accentRed,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.mediaPath ?? "Unknown File",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.link, size: 12),
                label: const Text("Relink Media", style: TextStyle(fontSize: 10)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StudioTheme.surfaceElevated,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  side: const BorderSide(color: StudioTheme.accentRed, width: 1),
                ),
                onPressed: () async {
                  if (widget.onRelink != null) {
                    try {
                      final picked = await PlatformFilePicker.pickMediaFiles(
                        allowMultiple: false,
                        dialogTitle: "Relink Missing Media: ${widget.mediaPath?.split('/').last}",
                      );
                      if (picked.isNotEmpty) {
                        widget.onRelink!(picked.first);
                        return;
                      }
                    } catch (_) {}
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Relinking search initiated for: ${widget.mediaPath}"),
                      backgroundColor: StudioTheme.surfaceElevated,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildSyntheticRaster() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D1117),
            Color(0xFF161B22),
            StudioTheme.surfaceElevated,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Center Grid / Crosshair
          Center(
            child: Icon(
              Icons.videocam,
              size: 48,
              color: StudioTheme.accentCyan.withValues(alpha: 0.2),
            ),
          ),
          // Precision Safe Area Crossbars
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: StudioTheme.accentCyan.withValues(alpha: 0.15)),
              ),
            ),
          ),
          // Bottom Color Calibrated Bar Line
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 4,
            child: Row(
              children: [
                Expanded(child: Container(color: const Color(0xFFC0C0C0))),
                Expanded(child: Container(color: const Color(0xFFC0C000))),
                Expanded(child: Container(color: const Color(0xFF00C0C0))),
                Expanded(child: Container(color: const Color(0xFF00C000))),
                Expanded(child: Container(color: const Color(0xFFC000C0))),
                Expanded(child: Container(color: const Color(0xFFC00000))),
                Expanded(child: Container(color: const Color(0xFF0000C0))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

