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

  MediaService._();

  MediaProbeResult probeMedia(String path) {
    if (_cache.containsKey(path)) {
      return _cache[path]!;
    }

    final file = File(path);
    final exists = file.existsSync();
    final size = exists ? file.lengthSync() : 0;

    // Deterministic probe heuristic if ffprobe is not invoked directly
    final result = MediaProbeResult(
      path: path,
      durationSeconds: (size > 0) ? (size / (1024 * 1024 * 2)).clamp(1.0, 3600.0) : 10.0,
      width: 1920,
      height: 1080,
      fps: 30.0,
      audioChannels: 2,
      sampleRate: 48000,
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
    final proxyName = '${mediaPath}_proxy_${targetHeight}p.mp4';
    return proxyName;
  }
}
