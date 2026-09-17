import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/timecode.dart';
import '../models/project_model.dart';
import '../models/track_model.dart';
import '../models/clip_model.dart';

class TimelineView extends StatefulWidget {
  final ProjectModel project;
  final double playheadTime;
  final ValueChanged<double> onPlayheadSeek;
  final ValueChanged<ClipModel?> onClipSelected;
  final ClipModel? selectedClip;
  final VoidCallback onSplitAtPlayhead;
  final VoidCallback onRippleDeleteSelected;

  const TimelineView({
    super.key,
    required this.project,
    required this.playheadTime,
    required this.onPlayheadSeek,
    required this.onClipSelected,
    this.selectedClip,
    required this.onSplitAtPlayhead,
    required this.onRippleDeleteSelected,
  });

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  double _pixelsPerSecond = 80.0;
  bool _snappingEnabled = true;

  @override
  Widget build(BuildContext context) {
    double totalTimelineWidth = (widget.project.duration * _pixelsPerSecond).clamp(800.0, 10000.0);

    return Column(
      children: [
        // Timeline Header Controls
        Container(
          height: 36,
          color: StudioTheme.surfaceElevated,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.content_cut, size: 16),
                tooltip: "Split at Playhead (S)",
                onPressed: widget.onSplitAtPlayhead,
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, size: 16),
                tooltip: "Ripple Delete Selected (Del)",
                onPressed: widget.onRippleDeleteSelected,
              ),
              const SizedBox(width: 8),
              // Snapping Toggle
              FilterChip(
                label: const Text("Snap", style: TextStyle(fontSize: 11)),
                selected: _snappingEnabled,
                onSelected: (v) => setState(() => _snappingEnabled = v),
                selectedColor: StudioTheme.accentCyan.withOpacity(0.2),
                checkmarkColor: StudioTheme.accentCyan,
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              // Zoom Controls
              const Icon(Icons.zoom_out, size: 16, color: StudioTheme.textSecondary),
              SizedBox(
                width: 120,
                child: Slider(
                  value: _pixelsPerSecond,
                  min: 20.0,
                  max: 200.0,
                  onChanged: (v) => setState(() => _pixelsPerSecond = v),
                ),
              ),
              const Icon(Icons.zoom_in, size: 16, color: StudioTheme.textSecondary),
            ],
          ),
        ),

        // Tracks and Ruler Scroll View
        Expanded(
          child: Row(
            children: [
              // Left Track Headers Column
              Container(
                width: 140,
                color: StudioTheme.surface,
                child: Column(
                  children: [
                    // Empty corner above tracks for timecode ruler alignment
                    Container(height: 28, color: StudioTheme.surfaceHighlight),
                    ...widget.project.tracks.map((track) {
                      return Container(
                        height: 56,
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: StudioTheme.border)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              track.trackType == TrackType.video
                                  ? Icons.videocam
                                  : track.trackType == TrackType.audio
                                      ? Icons.audiotrack
                                      : Icons.subtitles,
                              size: 16,
                              color: track.trackType == TrackType.video
                                  ? StudioTheme.accentCyan
                                  : track.trackType == TrackType.audio
                                      ? StudioTheme.accentEmerald
                                      : StudioTheme.accentAmber,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                track.name,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Mute button
                            GestureDetector(
                              onTap: () => setState(() => track.muted = !track.muted),
                              child: Icon(
                                track.muted ? Icons.volume_off : Icons.volume_up,
                                size: 14,
                                color: track.muted ? StudioTheme.accentRed : StudioTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

              // Right Tracks Canvas
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalTimelineWidth,
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Time Ruler
                            GestureDetector(
                              onTapDown: (details) {
                                double seekSec = details.localPosition.dx / _pixelsPerSecond;
                                widget.onPlayheadSeek(seekSec.clamp(0.0, widget.project.duration));
                              },
                              child: Container(
                                height: 28,
                                color: StudioTheme.surfaceHighlight,
                                child: CustomPaint(
                                  size: Size(totalTimelineWidth, 28),
                                  painter: RulerPainter(pixelsPerSecond: _pixelsPerSecond),
                                ),
                              ),
                            ),

                            // Track Lanes
                            ...widget.project.tracks.map((track) {
                              return Container(
                                height: 56,
                                width: totalTimelineWidth,
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: StudioTheme.border)),
                                ),
                                child: Stack(
                                  children: track.clips.map((clip) {
                                    final isSelected = widget.selectedClip?.id == clip.id;
                                    double left = clip.startTime * _pixelsPerSecond;
                                    double width = (clip.duration * _pixelsPerSecond).clamp(20.0, totalTimelineWidth);

                                    return Positioned(
                                      left: left,
                                      top: 4,
                                      bottom: 4,
                                      width: width,
                                      child: GestureDetector(
                                        onTap: () => widget.onClipSelected(clip),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? StudioTheme.accentCyan.withOpacity(0.35)
                                                : track.trackType == TrackType.video
                                                    ? StudioTheme.accentBlue.withOpacity(0.4)
                                                    : StudioTheme.accentEmerald.withOpacity(0.3),
                                            border: Border.all(
                                              color: isSelected
                                                  ? StudioTheme.accentCyan
                                                  : track.trackType == TrackType.video
                                                      ? StudioTheme.accentBlue
                                                      : StudioTheme.accentEmerald,
                                              width: isSelected ? 2 : 1,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: ClipRect(
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    clip.name,
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (width > 70)
                                                  Text(
                                                    TimecodeHelper.formatDurationSeconds(clip.duration),
                                                    style: const TextStyle(fontSize: 10, color: StudioTheme.textSecondary),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            }).toList(),
                          ],
                        ),

                        // Playhead Indicator Line
                        Positioned(
                          left: widget.playheadTime * _pixelsPerSecond - 1,
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: Container(
                              width: 2,
                              color: StudioTheme.accentCyan,
                              child: Column(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: StudioTheme.accentCyan,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RulerPainter extends CustomPainter {
  final double pixelsPerSecond;

  RulerPainter({required this.pixelsPerSecond});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StudioTheme.textMuted
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(color: StudioTheme.textSecondary, fontSize: 9);

    int totalSeconds = (size.width / pixelsPerSecond).ceil();
    for (int s = 0; s <= totalSeconds; s++) {
      double x = s * pixelsPerSecond;
      // Second tick
      canvas.drawLine(Offset(x, size.height - 12), Offset(x, size.height), paint);

      // Label every 1 second
      final textSpan = TextSpan(text: '${s}s', style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 2, 4));

      // Sub-second half tick
      double midX = x + pixelsPerSecond / 2;
      canvas.drawLine(Offset(midX, size.height - 6), Offset(midX, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant RulerPainter oldDelegate) {
    return oldDelegate.pixelsPerSecond != pixelsPerSecond;
  }
}
