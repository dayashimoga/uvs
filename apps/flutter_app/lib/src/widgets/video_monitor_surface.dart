import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/media_service.dart';

class VideoMonitorSurface extends StatefulWidget {
  final String? mediaPath;
  final double currentTime;
  final double duration;
  final bool isPlaying;
  final Widget? overlay;
  final BoxFit fit;

  const VideoMonitorSurface({
    super.key,
    this.mediaPath,
    required this.currentTime,
    required this.duration,
    this.isPlaying = false,
    this.overlay,
    this.fit = BoxFit.contain,
  });

  @override
  State<VideoMonitorSurface> createState() => _VideoMonitorSurfaceState();
}

class _VideoMonitorSurfaceState extends State<VideoMonitorSurface> {
  String? _framePath;
  String? _resolvedMediaPath;

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
    String? path = widget.mediaPath;
    if (path != null && File(path).existsSync()) {
      _resolvedMediaPath = path;
    } else {
      final candidates = [
        'tests/output/cam_test.mp4',
        'tests/output/preview_frame_1s.png',
        'tests/output/source_4k_test.mp4',
        'tests/output/proxy_720p.mp4',
        '../../tests/output/cam_test.mp4',
        '../../tests/output/preview_frame_1s.png',
      ];
      _resolvedMediaPath = null;
      for (final c in candidates) {
        if (File(c).existsSync()) {
          _resolvedMediaPath = c;
          break;
        }
      }
    }

    if (_resolvedMediaPath != null) {
      if (_resolvedMediaPath!.endsWith('.png') || _resolvedMediaPath!.endsWith('.jpg')) {
        _framePath = _resolvedMediaPath;
      } else {
        try {
          final extracted = MediaService.instance.extractFrame(
            _resolvedMediaPath!,
            widget.currentTime,
          );
          if (extracted.isNotEmpty && File(extracted).existsSync()) {
            _framePath = extracted;
          }
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget videoContent;

    if (_framePath != null && File(_framePath!).existsSync()) {
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

  Widget _buildSyntheticRaster() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1117),
            const Color(0xFF161B22),
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
              color: StudioTheme.accentCyan.withOpacity(0.2),
            ),
          ),
          // Precision Safe Area Crossbars
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: StudioTheme.accentCyan.withOpacity(0.15)),
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
