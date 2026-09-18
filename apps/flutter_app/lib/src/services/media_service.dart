import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/ffi_bridge.dart';

class MediaProbeResult {
  final String path;
  final double durationSeconds;
  final int width;
  final int height;
  final double fps;
  final int audioChannels;
  final int sampleRate;
  final String? proxyPath;

  const MediaProbeResult({
    required this.path,
    required this.durationSeconds,
    required this.width,
    required this.height,
    required this.fps,
    required this.audioChannels,
    required this.sampleRate,
    this.proxyPath,
  });
}

class MediaService extends ChangeNotifier {
  static MediaService? _instance;
  static MediaService get instance => _instance ??= MediaService._();

  final Map<String, MediaProbeResult> _cache = {};
  final Map<String, List<double>> _waveformCache = {};
  final Map<String, String> _frameCache = {};

  MediaService._();

  MediaProbeResult probeMedia(String path) {
    if (_cache.containsKey(path)) {
      return _cache[path]!;
    }

    final raw = UvsFfiBridge.instance.probeMedia(path);
    double duration = 10.0;
    int width = 1920;
    int height = 1080;
    double fps = 30.0;
    int audioChannels = 2;
    int sampleRate = 48000;

    if (raw.containsKey('format')) {
      final fmt = raw['format'];
      if (fmt is Map && fmt.containsKey('duration')) {
        duration = double.tryParse(fmt['duration']?.toString() ?? '') ?? 10.0;
      }
    }

    if (raw.containsKey('streams') && raw['streams'] is List) {
      for (final s in raw['streams'] as List) {
        if (s is Map) {
          if (s['codec_type'] == 'video') {
            width = int.tryParse(s['width']?.toString() ?? '') ?? width;
            height = int.tryParse(s['height']?.toString() ?? '') ?? height;
            final rFps = s['r_frame_rate']?.toString() ?? '';
            if (rFps.contains('/')) {
              final parts = rFps.split('/');
              final num = double.tryParse(parts[0]) ?? 30.0;
              final den = double.tryParse(parts[1]) ?? 1.0;
              fps = (den > 0) ? num / den : 30.0;
            }
          } else if (s['codec_type'] == 'audio') {
            audioChannels = int.tryParse(s['channels']?.toString() ?? '') ?? audioChannels;
            sampleRate = int.tryParse(s['sample_rate']?.toString() ?? '') ?? sampleRate;
          }
        }
      }
    }

    final result = MediaProbeResult(
      path: path,
      durationSeconds: duration,
      width: width,
      height: height,
      fps: fps,
      audioChannels: audioChannels,
      sampleRate: sampleRate,
    );

    _cache[path] = result;
    return result;
  }

  List<double> getWaveform(String path, {int points = 100}) {
    if (_waveformCache.containsKey(path)) {
      return _waveformCache[path]!;
    }
    final summary = UvsFfiBridge.instance.getWaveformSummary(48000 * 5, points);
    _waveformCache[path] = summary;
    return summary;
  }

  String createProxy(String mediaPath, {int targetHeight = 720}) {
    final targetPath = '${mediaPath}_proxy_${targetHeight}p.mp4';
    final res = UvsFfiBridge.instance.generateProxy(mediaPath, targetPath, targetHeight);
    return res['proxy_path'] as String? ?? targetPath;
  }

  String extractFrame(String mediaPath, double timeS, {String? outPngPath}) {
    final key = '${mediaPath}_${timeS.toStringAsFixed(2)}';
    if (_frameCache.containsKey(key)) {
      final cached = _frameCache[key]!;
      if (File(cached).existsSync()) {
        return cached;
      }
    }
    final targetOut = outPngPath ?? '${Directory.systemTemp.path}/uvs_frame_${DateTime.now().microsecondsSinceEpoch}.png';
    final res = UvsFfiBridge.instance.decodeFrame(mediaPath, timeS, targetOut);
    final outPath = res['path'] as String? ?? targetOut;
    if (outPath.isNotEmpty) {
      _frameCache[key] = outPath;
    }
    return outPath;
  }
}
