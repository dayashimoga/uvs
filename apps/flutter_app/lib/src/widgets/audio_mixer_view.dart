import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/project_model.dart';
import '../models/track_model.dart';

class AudioMixerView extends StatefulWidget {
  final ProjectModel project;

  const AudioMixerView({super.key, required this.project});

  @override
  State<AudioMixerView> createState() => _AudioMixerViewState();
}

class _AudioMixerViewState extends State<AudioMixerView> {
  double _masterVolume = 1.0;
  // 5-band EQ gains in dB (-12 to +12)
  double _eqLowShelf = 0.0;
  double _eqLowMid = 1.5;
  double _eqMid = -0.5;
  double _eqHighMid = 2.0;
  double _eqHighShelf = 0.5;

  // Compressor
  double _compThreshold = -18.0;
  double _compRatio = 3.0;

  @override
  Widget build(BuildContext context) {
    final audioTracks = widget.project.tracks.where((t) => t.trackType == TrackType.audio).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          const Text("Studio Audio Mixer & DSP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(color: StudioTheme.border, height: 20),

          // Master Fader and Meters
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Master Strip
              Container(
                width: 100,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: StudioTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: StudioTheme.accentCyan.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Text("MASTER", style: TextStyle(color: StudioTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 11)),
                    const SizedBox(height: 8),
                    // Stereo Meter Bars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMeterBar(0.75, StudioTheme.accentEmerald),
                        const SizedBox(width: 4),
                        _buildMeterBar(0.72, StudioTheme.accentEmerald),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        value: _masterVolume,
                        min: 0.0,
                        max: 1.5,
                        onChanged: (v) => setState(() => _masterVolume = v),
                      ),
                    ),
                    Text("${(_masterVolume * 100).round()}%", style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Per-Track Audio Strips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: audioTracks.map((t) {
                      return Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: StudioTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: StudioTheme.border),
                        ),
                        child: Column(
                          children: [
                            Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            _buildMeterBar(t.muted ? 0.0 : 0.65, StudioTheme.accentCyan),
                            const SizedBox(height: 6),
                            RotatedBox(
                              quarterTurns: 3,
                              child: Slider(
                                value: t.volume,
                                min: 0.0,
                                max: 1.5,
                                onChanged: (v) => setState(() => t.volume = v),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ChoiceChip(
                                  label: const Text("M", style: TextStyle(fontSize: 9)),
                                  selected: t.muted,
                                  onSelected: (s) => setState(() => t.muted = s),
                                  selectedColor: StudioTheme.accentRed,
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: 4),
                                ChoiceChip(
                                  label: const Text("S", style: TextStyle(fontSize: 9)),
                                  selected: t.solo,
                                  onSelected: (s) => setState(() => t.solo = s),
                                  selectedColor: StudioTheme.accentAmber,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          // 5-Band Equalizer
          const Text("5-Band Parametric Equalizer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildEqBand("100Hz", _eqLowShelf, (v) => setState(() => _eqLowShelf = v)),
              _buildEqBand("500Hz", _eqLowMid, (v) => setState(() => _eqLowMid = v)),
              _buildEqBand("1.5kHz", _eqMid, (v) => setState(() => _eqMid = v)),
              _buildEqBand("4kHz", _eqHighMid, (v) => setState(() => _eqHighMid = v)),
              _buildEqBand("10kHz", _eqHighShelf, (v) => setState(() => _eqHighShelf = v)),
            ],
          ),

          const SizedBox(height: 20),
          // Dynamic Compressor
          const Text("Dynamic Compressor / Limiter", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text("Threshold: ${_compThreshold.toStringAsFixed(1)} dB", style: const TextStyle(fontSize: 11, color: StudioTheme.textSecondary)),
          Slider(
            min: -40.0,
            max: 0.0,
            value: _compThreshold,
            onChanged: (v) => setState(() => _compThreshold = v),
          ),
          Text("Ratio: ${_compRatio.toStringAsFixed(1)} : 1", style: const TextStyle(fontSize: 11, color: StudioTheme.textSecondary)),
          Slider(
            min: 1.0,
            max: 10.0,
            value: _compRatio,
            onChanged: (v) => setState(() => _compRatio = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMeterBar(double fillFraction, Color color) {
    return Container(
      width: 8,
      height: 70,
      decoration: BoxDecoration(
        color: StudioTheme.surfaceHighlight,
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 70 * fillFraction.clamp(0.0, 1.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildEqBand(String label, double val, ValueChanged<double> onChanged) {
    return Column(
      children: [
        SizedBox(
          height: 80,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              min: -12.0,
              max: 12.0,
              value: val,
              onChanged: onChanged,
            ),
          ),
        ),
        Text("${val > 0 ? '+' : ''}${val.toStringAsFixed(1)}dB", style: const TextStyle(fontSize: 10, color: StudioTheme.accentCyan)),
        Text(label, style: const TextStyle(fontSize: 10, color: StudioTheme.textSecondary)),
      ],
    );
  }
}
