import 'package:flutter/material.dart';
import '../core/theme.dart';

class ColorInspectorView extends StatefulWidget {
  const ColorInspectorView({super.key});

  @override
  State<ColorInspectorView> createState() => _ColorInspectorViewState();
}

class _ColorInspectorViewState extends State<ColorInspectorView> {
  double _exposure = 0.0;
  double _contrast = 1.0;
  double _highlights = 0.0;
  double _shadows = 0.0;
  double _temperature = 0.0;
  double _tint = 0.0;
  double _saturation = 1.0;
  String _selectedLut = 'None';

  final List<String> _lutOptions = [
    'None',
    'Teal & Orange Rec709',
    'Cinematic Warm 3D',
    'Monochrome Noir',
    'Bleach Bypass',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          const Text("Color Grading & Visuals", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(color: StudioTheme.border, height: 20),

          // 3D LUT Loader
          const Text("3D LUT Profile (.cube)", style: TextStyle(color: StudioTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButton<String>(
            isExpanded: true,
            value: _selectedLut,
            dropdownColor: StudioTheme.surfaceElevated,
            items: _lutOptions.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedLut = v);
            },
          ),
          const SizedBox(height: 16),

          // Primary Adjustments
          _buildSlider("Exposure (EV)", _exposure, -3.0, 3.0, (v) => setState(() => _exposure = v)),
          _buildSlider("Contrast", _contrast, 0.5, 2.0, (v) => setState(() => _contrast = v)),
          _buildSlider("Highlights", _highlights, -1.0, 1.0, (v) => setState(() => _highlights = v)),
          _buildSlider("Shadows", _shadows, -1.0, 1.0, (v) => setState(() => _shadows = v)),
          _buildSlider("Temperature", _temperature, -50.0, 50.0, (v) => setState(() => _temperature = v)),
          _buildSlider("Tint", _tint, -50.0, 50.0, (v) => setState(() => _tint = v)),
          _buildSlider("Saturation", _saturation, 0.0, 2.0, (v) => setState(() => _saturation = v)),

          const SizedBox(height: 16),
          // 3 Color Wheels (Lift, Gamma, Gain)
          const Text("Color Wheels", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildColorWheel("LIFT", StudioTheme.accentCyan),
              _buildColorWheel("GAMMA", StudioTheme.accentAmber),
              _buildColorWheel("GAIN", StudioTheme.accentEmerald),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double val, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: StudioTheme.textSecondary)),
            Text(val.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: StudioTheme.accentCyan, fontFamily: 'monospace')),
          ],
        ),
        Slider(min: min, max: max, value: val, onChanged: onChanged),
      ],
    );
  }

  Widget _buildColorWheel(String label, Color accent) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: StudioTheme.border, width: 2),
            gradient: const SweepGradient(
              colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red],
            ),
          ),
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
