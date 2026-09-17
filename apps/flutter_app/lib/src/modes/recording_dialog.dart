import 'package:flutter/material.dart';
import '../core/theme.dart';

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
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioTheme.surfaceElevated,
      title: const Row(
        children: [
          Icon(Icons.fiber_manual_record, color: StudioTheme.accentRed),
          SizedBox(width: 8),
          Text("Screen & Camera Recording"),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text("Capture Screen / Window"),
            value: _recordScreen,
            activeColor: StudioTheme.accentCyan,
            onChanged: (v) => setState(() => _recordScreen = v),
          ),
          SwitchListTile(
            title: const Text("Capture Facecam (PiP)"),
            value: _recordCamera,
            activeColor: StudioTheme.accentCyan,
            onChanged: (v) => setState(() => _recordCamera = v),
          ),
          SwitchListTile(
            title: const Text("Capture Microphone Audio"),
            value: _recordMic,
            activeColor: StudioTheme.accentCyan,
            onChanged: (v) => setState(() => _recordMic = v),
          ),
          const SizedBox(height: 12),
          DropdownButton<String>(
            isExpanded: true,
            value: _selectedResolution,
            dropdownColor: StudioTheme.surfaceHighlight,
            items: ["1080p 60fps", "4K 30fps", "720p 60fps"].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedResolution = v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton.icon(
          icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record, color: Colors.white, size: 18),
          label: Text(_isRecording ? "Stop Recording" : "Start Recording"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRecording ? StudioTheme.accentRed : StudioTheme.accentCyan,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            setState(() => _isRecording = !_isRecording);
            if (!_isRecording) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Recording saved and automatically imported to Studio Media Bin")),
              );
            }
          },
        ),
      ],
    );
  }
}
