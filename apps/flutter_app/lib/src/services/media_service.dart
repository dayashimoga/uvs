import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/ffi_bridge.dart';
import 'platform_file_picker.dart';
import 'recent_media_service.dart';

class MediaProbeResult {
  final String path;
  final double durationSeconds;
  final int width;
  final int height;
  final double fps;
  final int audioChannels;
  final int sampleRate;
  final String? proxyPath;
  final String? thumbnailPath;

  const MediaProbeResult({
    required this.path,
    required this.durationSeconds,
    required this.width,
    required this.height,
    required this.fps,
    required this.audioChannels,
    required this.sampleRate,
    this.proxyPath,
    this.thumbnailPath,
  });

  String get fileName {
    final norm = path.replaceAll('\\', '/');
    return norm.split('/').last;
  }

  String get resolutionString => '${width}x$height';
  String get fpsString => '${fps.toStringAsFixed(fps.truncateToDouble() == fps ? 0 : 2)} fps';
}

class MediaService extends ChangeNotifier {
  static MediaService? _instance;
  static MediaService get instance => _instance ??= MediaService._();

  final Map<String, MediaProbeResult> _cache = {};
  final Map<String, List<double>> _waveformCache = {};
  final Map<String, String> _frameCache = {};

  MediaService._();

  /// Resolves fixture paths across both root execution and apps/flutter_app test runners
  static String? resolveFixture(String relPath) {
    if (File(relPath).existsSync()) return relPath;
    final twoUp = '../../$relPath';
    if (File(twoUp).existsSync()) return twoUp;
    final oneUp = '../$relPath';
    if (File(oneUp).existsSync()) return oneUp;
    return null;
  }

  /// Strictly validates file existence on disk, probes metadata via native engine,
  /// extracts initial preview frame, registers into recent media, and caches result.
  /// Throws [FileSystemException] or [ArgumentError] if file does not exist.
  MediaProbeResult validateAndIngestMedia(String rawPath) {
    final cleanPath = rawPath.trim().replaceAll('"', '');
    if (cleanPath.isEmpty) {
      throw ArgumentError('Media path cannot be empty.');
    }

    final file = File(cleanPath);
    if (!file.existsSync()) {
      throw FileSystemException('Media file does not exist on disk', cleanPath);
    }

    final canonicalPath = file.resolveSymbolicLinksSync();
    final probe = probeMedia(canonicalPath);

    // Pre-extract frame 0.0 for instant thumbnail rendering
    try {
      final thumb = extractFrame(canonicalPath, 0.0);
      RecentMediaService.instance.addRecentMedia(canonicalPath);
      final enriched = MediaProbeResult(
        path: probe.path,
        durationSeconds: probe.durationSeconds,
        width: probe.width,
        height: probe.height,
        fps: probe.fps,
        audioChannels: probe.audioChannels,
        sampleRate: probe.sampleRate,
        proxyPath: probe.proxyPath,
        thumbnailPath: thumb,
      );
      _cache[canonicalPath] = enriched;
      notifyListeners();
      return enriched;
    } catch (_) {
      RecentMediaService.instance.addRecentMedia(canonicalPath);
      return probe;
    }
  }

  /// Interactively pick media files using the native platform dialog and ingest each.
  Future<List<MediaProbeResult>> pickAndIngestMedia({
    bool allowMultiple = true,
    String dialogTitle = "Open Media File",
  }) async {
    final paths = await PlatformFilePicker.pickMediaFiles(
      allowMultiple: allowMultiple,
      dialogTitle: dialogTitle,
    );

    final results = <MediaProbeResult>[];
    for (final p in paths) {
      try {
        final res = validateAndIngestMedia(p);
        results.add(res);
      } catch (e) {
        debugPrint("Failed to ingest picked media $p: $e");
      }
    }
    return results;
  }

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

  void clearCache() {
    _cache.clear();
    _waveformCache.clear();
    _frameCache.clear();
    notifyListeners();
  }
}
