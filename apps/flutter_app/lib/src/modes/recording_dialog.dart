import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/recording_service.dart';
import '../services/project_service.dart';

class RecordingDialog extends StatefulWidget {
  const RecordingDialog({super.key});

  @override
  State<RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<RecordingDialog> {
  bool _recordScreen = true;
  bool _recordCamera = true;
  bool _recordMic = true;
  bool _isRecording = false;
  String _selectedResolution = "1080p 60fps";

  @override
  void dispose() {
    if (RecordingService.instance.isRecording) {
      RecordingService.instance.stopRecording();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rec = RecordingService.instance;
    final isRec = _isRecording || rec.isRecording;
    final elapsed = rec.elapsedSeconds;
    final minutes = (elapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsed % 60).toString().padLeft(2, '0');

    return AlertDialog(
      backgroundColor: StudioTheme.surfaceElevated,
      title: Row(
        children: [
          Icon(
            isRec ? Icons.radio_button_checked : Icons.fiber_manual_record,
            color: StudioTheme.accentRed,
          ),
          const SizedBox(width: 8),
          Text(isRec ? "Recording ($minutes:$seconds)" : "Screen & Camera Recording"),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text("Capture Screen / Window"),
            value: _recordScreen,
            activeColor: StudioTheme.accentCyan,
            onChanged: isRec ? null : (v) => setState(() => _recordScreen = v),
          ),
          SwitchListTile(
            title: const Text("Capture Facecam (PiP)"),
            value: _recordCamera,
            activeColor: StudioTheme.accentCyan,
            onChanged: isRec ? null : (v) => setState(() => _recordCamera = v),
          ),
          SwitchListTile(
            title: const Text("Capture Microphone Audio"),
            value: _recordMic,
            activeColor: StudioTheme.accentCyan,
            onChanged: isRec ? null : (v) => setState(() => _recordMic = v),
          ),
          const SizedBox(height: 12),
          DropdownButton<String>(
            isExpanded: true,
            value: _selectedResolution,
            dropdownColor: StudioTheme.surfaceHighlight,
            items: ["1080p 60fps", "4K 30fps", "720p 60fps"].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: isRec
                ? null
                : (v) {
                    if (v != null) setState(() => _selectedResolution = v);
                  },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (isRec) {
              rec.stopRecording();
            }
            Navigator.pop(context);
          },
          child: const Text("Cancel"),
        ),
        ElevatedButton.icon(
          icon: Icon(isRec ? Icons.stop : Icons.fiber_manual_record, color: Colors.white, size: 18),
          label: Text(isRec ? "Stop Recording" : "Start Recording"),
          style: ElevatedButton.styleFrom(
            backgroundColor: isRec ? StudioTheme.accentRed : StudioTheme.accentCyan,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            setState(() {
              _isRecording = !_isRecording;
              if (_isRecording) {
                if (_recordScreen && !rec.activeSources.contains(RecordingSource.screen)) {
                  rec.toggleSource(RecordingSource.screen);
                }
                if (_recordCamera && !rec.activeSources.contains(RecordingSource.camera)) {
                  rec.toggleSource(RecordingSource.camera);
                }
                if (_recordMic && !rec.activeSources.contains(RecordingSource.microphone)) {
                  rec.toggleSource(RecordingSource.microphone);
                }
                if (rec.activeSources.isEmpty) {
                  rec.toggleSource(RecordingSource.screen);
                }
                rec.startRecording();
              } else {
                final outPath = rec.stopRecording();
                if (outPath.isNotEmpty) {
                  try {
                    final tracks = (ProjectService.instance.project['timeline']?['tracks'] as List?) ?? [];
                    final vTrack = tracks.firstWhere((t) => t['track_type'] == 'Video', orElse: () => null);
                    final trackId = vTrack != null ? vTrack['id'] as String : 'track-v1';
                    ProjectService.instance.addClip(
                      trackId,
                      'Recording (${_selectedResolution.split(" ").first})',
                      outPath,
                      0.0,
                      elapsed > 0 ? elapsed.toDouble() : 4.0,
                    );
                  } catch (_) {}
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Recording saved ($outPath) and imported to Studio Media Bin")),
                );
              }
            });
          },
        ),
      ],
    );
  }
}
