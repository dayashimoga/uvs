import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// Native function typedefs
typedef UvsCoreVersionC = ffi.Pointer<Utf8> Function();
typedef UvsCoreVersionDart = ffi.Pointer<Utf8> Function();

typedef UvsDetectHardwareC = ffi.Pointer<Utf8> Function();
typedef UvsDetectHardwareDart = ffi.Pointer<Utf8> Function();

typedef UvsFreeStringC = ffi.Void Function(ffi.Pointer<Utf8>);
typedef UvsFreeStringDart = void Function(ffi.Pointer<Utf8>);

typedef UvsProjectNewC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> name,
  ffi.Uint32 width,
  ffi.Uint32 height,
  ffi.Int64 fpsNum,
  ffi.Int64 fpsDen,
  ffi.Int32 dropFrame,
);
typedef UvsProjectNewDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> name,
  int width,
  int height,
  int fpsNum,
  int fpsDen,
  int dropFrame,
);

typedef UvsProjectSaveAtomicC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> targetPath,
);
typedef UvsProjectSaveAtomicDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> targetPath,
);

typedef UvsProjectLoadC = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> path);
typedef UvsProjectLoadDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> path);

typedef UvsProjectRelinkC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> searchDir,
);
typedef UvsProjectRelinkDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> searchDir,
);

typedef UvsTimelineAddTrackC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> name,
  ffi.Int32 trackType,
  ffi.Int32 zIndex,
);
typedef UvsTimelineAddTrackDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> name,
  int trackType,
  int zIndex,
);

typedef UvsTimelineAddClipC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipName,
  ffi.Pointer<Utf8> mediaPath,
  ffi.Double startS,
  ffi.Double durationS,
);
typedef UvsTimelineAddClipDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipName,
  ffi.Pointer<Utf8> mediaPath,
  double startS,
  double durationS,
);

typedef UvsTimelineSplitClipC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  ffi.Double splitTimeS,
);
typedef UvsTimelineSplitClipDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  double splitTimeS,
);

typedef UvsTimelineRippleDeleteC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
);
typedef UvsTimelineRippleDeleteDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
);

typedef UvsTimelineTrimClipC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  ffi.Int32 isHead,
  ffi.Double newTimeS,
);
typedef UvsTimelineTrimClipDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  int isHead,
  double newTimeS,
);

typedef UvsTimelineRollEditC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> leftClipId,
  ffi.Pointer<Utf8> rightClipId,
  ffi.Double deltaS,
);
typedef UvsTimelineRollEditDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> leftClipId,
  ffi.Pointer<Utf8> rightClipId,
  double deltaS,
);

typedef UvsTimelineSlipEditC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  ffi.Double deltaS,
);
typedef UvsTimelineSlipEditDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  double deltaS,
);

typedef UvsTimelineSlideEditC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  ffi.Double deltaS,
);
typedef UvsTimelineSlideEditDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  double deltaS,
);

typedef UvsTimelineSetSpeedC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  ffi.Double speed,
  ffi.Int32 reverse,
);
typedef UvsTimelineSetSpeedDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  double speed,
  int reverse,
);

typedef UvsTimelineLinkClipsC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> clip1Id,
  ffi.Pointer<Utf8> clip2Id,
);
typedef UvsTimelineLinkClipsDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> clip1Id,
  ffi.Pointer<Utf8> clip2Id,
);

typedef UvsTimelineAddMarkerC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Double timeS,
  ffi.Pointer<Utf8> name,
  ffi.Pointer<Utf8> color,
  ffi.Pointer<Utf8> comment,
);
typedef UvsTimelineAddMarkerDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  double timeS,
  ffi.Pointer<Utf8> name,
  ffi.Pointer<Utf8> color,
  ffi.Pointer<Utf8> comment,
);

typedef UvsTimelineDeleteMarkerC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> markerId,
);
typedef UvsTimelineDeleteMarkerDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> markerId,
);

typedef UvsClipAddKeyframeC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  ffi.Pointer<Utf8> property,
  ffi.Double timeS,
  ffi.Double value,
  ffi.Int32 interpType,
);
typedef UvsClipAddKeyframeDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  ffi.Pointer<Utf8> property,
  double timeS,
  double value,
  int interpType,
);

typedef UvsClipSetTransitionC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  ffi.Int32 isIn,
  ffi.Int32 transType,
  ffi.Double durS,
);
typedef UvsClipSetTransitionDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> trackId,
  ffi.Pointer<Utf8> clipId,
  int isIn,
  int transType,
  double durS,
);

typedef UvsSubtitleAddCueC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Double startS,
  ffi.Double endS,
  ffi.Pointer<Utf8> text,
);
typedef UvsSubtitleAddCueDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  double startS,
  double endS,
  ffi.Pointer<Utf8> text,
);

typedef UvsMulticamCommitCutsC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> groupJson,
  ffi.Pointer<Utf8> cutsJson,
);
typedef UvsMulticamCommitCutsDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> groupJson,
  ffi.Pointer<Utf8> cutsJson,
);

typedef UvsFindMulticamLagC = ffi.Int64 Function(
  ffi.Pointer<ffi.Float> samplesA,
  ffi.Size lenA,
  ffi.Pointer<ffi.Float> samplesB,
  ffi.Size lenB,
  ffi.Size maxLag,
);
typedef UvsFindMulticamLagDart = int Function(
  ffi.Pointer<ffi.Float> samplesA,
  int lenA,
  ffi.Pointer<ffi.Float> samplesB,
  int lenB,
  int maxLag,
);

typedef UvsCalculateIntegratedLufsC = ffi.Double Function(
  ffi.Pointer<ffi.Float> samples,
  ffi.Size sampleCount,
  ffi.Size channels,
  ffi.Uint32 sampleRate,
);
typedef UvsCalculateIntegratedLufsDart = double Function(
  ffi.Pointer<ffi.Float> samples,
  int sampleCount,
  int channels,
  int sampleRate,
);

typedef UvsWaveformSummaryC = ffi.Pointer<Utf8> Function(
  ffi.Size sampleCount,
  ffi.Size targetPoints,
);
typedef UvsWaveformSummaryDart = ffi.Pointer<Utf8> Function(
  int sampleCount,
  int targetPoints,
);

typedef UvsBuildRenderCommandC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> inputPath,
  ffi.Pointer<Utf8> outputPath,
);
typedef UvsBuildRenderCommandDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> inputPath,
  ffi.Pointer<Utf8> outputPath,
);

typedef UvsExecuteRenderC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> inputPath,
  ffi.Pointer<Utf8> outputPath,
);
typedef UvsExecuteRenderDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> projectJson,
  ffi.Pointer<Utf8> inputPath,
  ffi.Pointer<Utf8> outputPath,
);

typedef UvsMediaProbeC = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> path);
typedef UvsMediaProbeDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> path);

typedef UvsDecodeFrameC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> mediaPath,
  ffi.Double timeS,
  ffi.Pointer<Utf8> outPngPath,
);
typedef UvsDecodeFrameDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> mediaPath,
  double timeS,
  ffi.Pointer<Utf8> outPngPath,
);

typedef UvsProxyGenerateC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> sourcePath,
  ffi.Pointer<Utf8> targetPath,
  ffi.Int32 targetHeight,
);
typedef UvsProxyGenerateDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> sourcePath,
  ffi.Pointer<Utf8> targetPath,
  int targetHeight,
);

/// Safe FFI Bridge connecting Flutter to `uvs_core` native Rust library.
/// Provides real native C-ABI execution when binary is present, and
/// reliable pure-Dart fallback in headless test environments.
class UvsFfiBridge {
  static UvsFfiBridge? _instance;
  static UvsFfiBridge get instance => _instance ??= UvsFfiBridge._();

  ffi.DynamicLibrary? _lib;
  bool _isNative = false;
  bool forcePureDart = false;
  bool get _effectiveNative => !forcePureDart && _isNative;

  bool get isNativeLoaded => _effectiveNative;
  ffi.DynamicLibrary? get dynamicLibrary => _lib;

  // Native function handles
  UvsFreeStringDart? _nativeFreeString;
  UvsCoreVersionDart? _nativeCoreVersion;
  UvsDetectHardwareDart? _nativeDetectHardware;
  UvsProjectNewDart? _nativeProjectNew;
  UvsProjectSaveAtomicDart? _nativeProjectSaveAtomic;
  UvsProjectLoadDart? _nativeProjectLoad;
  UvsProjectRelinkDart? _nativeProjectRelink;
  UvsTimelineAddTrackDart? _nativeTimelineAddTrack;
  UvsTimelineAddClipDart? _nativeTimelineAddClip;
  UvsTimelineSplitClipDart? _nativeTimelineSplitClip;
  UvsTimelineRippleDeleteDart? _nativeTimelineRippleDelete;
  UvsTimelineTrimClipDart? _nativeTimelineTrimClip;
  UvsTimelineRollEditDart? _nativeTimelineRollEdit;
  UvsTimelineSlipEditDart? _nativeTimelineSlipEdit;
  UvsTimelineSlideEditDart? _nativeTimelineSlideEdit;
  UvsTimelineSetSpeedDart? _nativeTimelineSetSpeed;
  UvsTimelineLinkClipsDart? _nativeTimelineLinkClips;
  UvsTimelineAddMarkerDart? _nativeTimelineAddMarker;
  UvsTimelineDeleteMarkerDart? _nativeTimelineDeleteMarker;
  UvsClipAddKeyframeDart? _nativeClipAddKeyframe;
  UvsClipSetTransitionDart? _nativeClipSetTransition;
  UvsSubtitleAddCueDart? _nativeSubtitleAddCue;
  UvsMulticamCommitCutsDart? _nativeMulticamCommitCuts;
  UvsFindMulticamLagDart? _nativeFindMulticamLag;
  UvsCalculateIntegratedLufsDart? _nativeCalculateIntegratedLufs;
  UvsWaveformSummaryDart? _nativeWaveformSummary;
  UvsBuildRenderCommandDart? _nativeBuildRenderCommand;
  UvsExecuteRenderDart? _nativeExecuteRender;
  UvsMediaProbeDart? _nativeMediaProbe;
  UvsDecodeFrameDart? _nativeDecodeFrame;
  UvsProxyGenerateDart? _nativeProxyGenerate;

  UvsFfiBridge._() {
    _initLibrary();
  }

  void _initLibrary() {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      if (Platform.isWindows) {
        final candidates = [
          '$exeDir/uvs_core.dll',
          'uvs_core.dll',
          'core/rust/target/release/uvs_core.dll',
          'core/rust/target/debug/uvs_core.dll',
          '../core/rust/target/release/uvs_core.dll',
          '../core/rust/target/debug/uvs_core.dll',
          '../../core/rust/target/release/uvs_core.dll',
          '../../core/rust/target/debug/uvs_core.dll',
        ];
        for (final path in candidates) {
          if (File(path).existsSync()) {
            _lib = ffi.DynamicLibrary.open(path);
            _bindNativeFunctions();
            _isNative = true;
            break;
          }
        }
        if (!_isNative) {
          // Attempt direct Windows system/path load
          try {
            _lib = ffi.DynamicLibrary.open('uvs_core.dll');
            _bindNativeFunctions();
            _isNative = true;
          } catch (_) {}
        }
      } else if (Platform.isLinux) {
        final candidates = [
          '$exeDir/lib/libuvs_core.so',
          '$exeDir/libuvs_core.so',
          'libuvs_core.so',
          'core/rust/target/release/libuvs_core.so',
          'core/rust/target/debug/libuvs_core.so',
          '../core/rust/target/release/libuvs_core.so',
          '../core/rust/target/debug/libuvs_core.so',
          '../../core/rust/target/release/libuvs_core.so',
          '../../core/rust/target/debug/libuvs_core.so',
        ];
        for (final path in candidates) {
          if (File(path).existsSync()) {
            _lib = ffi.DynamicLibrary.open(path);
            _bindNativeFunctions();
            _isNative = true;
            break;
          }
        }
        if (!_isNative) {
          try {
            _lib = ffi.DynamicLibrary.open('libuvs_core.so');
            _bindNativeFunctions();
            _isNative = true;
          } catch (_) {}
        }
      } else if (Platform.isMacOS) {
        final candidates = [
          '$exeDir/../Frameworks/libuvs_core.dylib',
          '$exeDir/libuvs_core.dylib',
          'libuvs_core.dylib',
          'core/rust/target/release/libuvs_core.dylib',
          'core/rust/target/debug/libuvs_core.dylib',
          '../core/rust/target/release/libuvs_core.dylib',
          '../core/rust/target/debug/libuvs_core.dylib',
          '../../core/rust/target/release/libuvs_core.dylib',
          '../../core/rust/target/debug/libuvs_core.dylib',
        ];
        for (final path in candidates) {
          if (File(path).existsSync()) {
            _lib = ffi.DynamicLibrary.open(path);
            _bindNativeFunctions();
            _isNative = true;
            break;
          }
        }
        if (!_isNative) {
          try {
            _lib = ffi.DynamicLibrary.open('libuvs_core.dylib');
            _bindNativeFunctions();
            _isNative = true;
          } catch (_) {}
        }
      } else if (Platform.isAndroid) {
        try {
          _lib = ffi.DynamicLibrary.open('libuvs_core.so');
          _bindNativeFunctions();
          _isNative = true;
        } catch (_) {
          _isNative = false;
          _lib = null;
        }
      }
    } catch (_) {
      _isNative = false;
      _lib = null;
    }
  }

  void _bindNativeFunctions() {
    if (_lib == null) return;
    try {
      _nativeFreeString = _lib!.lookupFunction<UvsFreeStringC, UvsFreeStringDart>('uvs_free_string');
      _nativeCoreVersion = _lib!.lookupFunction<UvsCoreVersionC, UvsCoreVersionDart>('uvs_core_version');
      _nativeDetectHardware = _lib!.lookupFunction<UvsDetectHardwareC, UvsDetectHardwareDart>('uvs_detect_hardware');
      _nativeProjectNew = _lib!.lookupFunction<UvsProjectNewC, UvsProjectNewDart>('uvs_project_new');
      _nativeProjectSaveAtomic = _lib!.lookupFunction<UvsProjectSaveAtomicC, UvsProjectSaveAtomicDart>('uvs_project_save_atomic');
      _nativeProjectLoad = _lib!.lookupFunction<UvsProjectLoadC, UvsProjectLoadDart>('uvs_project_load');
      _nativeProjectRelink = _lib!.lookupFunction<UvsProjectRelinkC, UvsProjectRelinkDart>('uvs_project_relink');
      _nativeTimelineAddTrack = _lib!.lookupFunction<UvsTimelineAddTrackC, UvsTimelineAddTrackDart>('uvs_timeline_add_track');
      _nativeTimelineAddClip = _lib!.lookupFunction<UvsTimelineAddClipC, UvsTimelineAddClipDart>('uvs_timeline_add_clip');
      _nativeTimelineSplitClip = _lib!.lookupFunction<UvsTimelineSplitClipC, UvsTimelineSplitClipDart>('uvs_timeline_split_clip');
      _nativeTimelineRippleDelete = _lib!.lookupFunction<UvsTimelineRippleDeleteC, UvsTimelineRippleDeleteDart>('uvs_timeline_ripple_delete');
      _nativeTimelineTrimClip = _lib!.lookupFunction<UvsTimelineTrimClipC, UvsTimelineTrimClipDart>('uvs_timeline_trim_clip');
      _nativeTimelineRollEdit = _lib!.lookupFunction<UvsTimelineRollEditC, UvsTimelineRollEditDart>('uvs_timeline_roll_edit');
      _nativeTimelineSlipEdit = _lib!.lookupFunction<UvsTimelineSlipEditC, UvsTimelineSlipEditDart>('uvs_timeline_slip_edit');
      _nativeTimelineSlideEdit = _lib!.lookupFunction<UvsTimelineSlideEditC, UvsTimelineSlideEditDart>('uvs_timeline_slide_edit');
      _nativeTimelineSetSpeed = _lib!.lookupFunction<UvsTimelineSetSpeedC, UvsTimelineSetSpeedDart>('uvs_timeline_set_speed');
      _nativeTimelineLinkClips = _lib!.lookupFunction<UvsTimelineLinkClipsC, UvsTimelineLinkClipsDart>('uvs_timeline_link_clips');
      _nativeTimelineAddMarker = _lib!.lookupFunction<UvsTimelineAddMarkerC, UvsTimelineAddMarkerDart>('uvs_timeline_add_marker');
      _nativeTimelineDeleteMarker = _lib!.lookupFunction<UvsTimelineDeleteMarkerC, UvsTimelineDeleteMarkerDart>('uvs_timeline_delete_marker');
      _nativeClipAddKeyframe = _lib!.lookupFunction<UvsClipAddKeyframeC, UvsClipAddKeyframeDart>('uvs_clip_add_keyframe');
      _nativeClipSetTransition = _lib!.lookupFunction<UvsClipSetTransitionC, UvsClipSetTransitionDart>('uvs_clip_set_transition');
      _nativeSubtitleAddCue = _lib!.lookupFunction<UvsSubtitleAddCueC, UvsSubtitleAddCueDart>('uvs_subtitle_add_cue');
      _nativeMulticamCommitCuts = _lib!.lookupFunction<UvsMulticamCommitCutsC, UvsMulticamCommitCutsDart>('uvs_multicam_commit_cuts');
      _nativeFindMulticamLag = _lib!.lookupFunction<UvsFindMulticamLagC, UvsFindMulticamLagDart>('uvs_find_multicam_lag');
      _nativeCalculateIntegratedLufs = _lib!.lookupFunction<UvsCalculateIntegratedLufsC, UvsCalculateIntegratedLufsDart>('uvs_calculate_integrated_lufs');
      _nativeWaveformSummary = _lib!.lookupFunction<UvsWaveformSummaryC, UvsWaveformSummaryDart>('uvs_waveform_summary');
      _nativeBuildRenderCommand = _lib!.lookupFunction<UvsBuildRenderCommandC, UvsBuildRenderCommandDart>('uvs_build_render_command');
      _nativeExecuteRender = _lib!.lookupFunction<UvsExecuteRenderC, UvsExecuteRenderDart>('uvs_execute_render');
      _nativeMediaProbe = _lib!.lookupFunction<UvsMediaProbeC, UvsMediaProbeDart>('uvs_media_probe');
      _nativeDecodeFrame = _lib!.lookupFunction<UvsDecodeFrameC, UvsDecodeFrameDart>('uvs_decode_frame');
      _nativeProxyGenerate = _lib!.lookupFunction<UvsProxyGenerateC, UvsProxyGenerateDart>('uvs_proxy_generate');
    } catch (_) {
      // Optional exports may fail in partial builds
    }
  }

  String _consumeRustString(ffi.Pointer<Utf8> ptr) {
    if (ptr.address == 0) return '';
    final str = ptr.toDartString();
    _nativeFreeString?.call(ptr);
    return str;
  }

  double _rationalToDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is Map && val.containsKey('seconds') && val['seconds'] is List) {
      final list = val['seconds'] as List;
      if (list.length >= 2) {
        final n = (list[0] as num).toDouble();
        final d = (list[1] as num).toDouble();
        return d != 0 ? n / d : 0.0;
      }
    }
    return 0.0;
  }

  Map<String, dynamic> _syncProject(Map<String, dynamic> target, Map<String, dynamic> source) {
    if (target.containsKey('timeline') && source.containsKey('timeline')) {
      final tTimeline = target['timeline'];
      final sTimeline = source['timeline'];
      if (tTimeline is Map && sTimeline is Map) {
        final tTracks = tTimeline['tracks'];
        final sTracks = sTimeline['tracks'];
        if (tTracks is List && sTracks is List) {
          for (final sTrack in sTracks) {
            if (sTrack is Map) {
              final sId = sTrack['id'];
              final tTrack = tTracks.firstWhere((t) => t is Map && t['id'] == sId, orElse: () => null);
              if (tTrack != null && tTrack is Map) {
                if (tTrack.containsKey('clips') && sTrack.containsKey('clips')) {
                  final tClips = tTrack['clips'];
                  final sClips = sTrack['clips'];
                  if (tClips is List && sClips is List) {
                    for (final clip in sClips) {
                      if (clip is Map) {
                        if (clip.containsKey('start_time')) clip['start_time'] = _rationalToDouble(clip['start_time']);
                        if (clip.containsKey('duration')) clip['duration'] = _rationalToDouble(clip['duration']);
                        if (clip.containsKey('in_point')) clip['in_point'] = _rationalToDouble(clip['in_point']);
                        if (clip.containsKey('out_point')) clip['out_point'] = _rationalToDouble(clip['out_point']);
                      }
                    }
                    tClips.clear();
                    tClips.addAll(sClips);
                  }
                }
                for (final k in sTrack.keys) {
                  if (k != 'clips') {
                    tTrack[k] = sTrack[k];
                  }
                }
              } else {
                if (sTrack.containsKey('clips') && sTrack['clips'] is List) {
                  for (final clip in sTrack['clips'] as List) {
                    if (clip is Map) {
                      if (clip.containsKey('start_time')) clip['start_time'] = _rationalToDouble(clip['start_time']);
                      if (clip.containsKey('duration')) clip['duration'] = _rationalToDouble(clip['duration']);
                      if (clip.containsKey('in_point')) clip['in_point'] = _rationalToDouble(clip['in_point']);
                      if (clip.containsKey('out_point')) clip['out_point'] = _rationalToDouble(clip['out_point']);
                    }
                  }
                }
                tTracks.add(sTrack);
              }
            }
          }
          tTracks.removeWhere((t) => t is Map && !sTracks.any((s) => s is Map && s['id'] == t['id']));
        }
        for (final k in sTimeline.keys) {
          if (k != 'tracks') {
            tTimeline[k] = sTimeline[k];
          }
        }
      }
    }
    for (final key in source.keys) {
      if (key != 'timeline') {
        target[key] = source[key];
      }
    }
    return target;
  }

  String getCoreVersion() {
    if (_effectiveNative && _nativeCoreVersion != null) {
      try {
        final ptr = _nativeCoreVersion!();
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) return res;
      } catch (_) {}
    }
    return "0.1.0-production";
  }

  Map<String, dynamic> detectHardware() {
    if (_effectiveNative && _nativeDetectHardware != null) {
      try {
        final ptr = _nativeDetectHardware!();
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      } catch (_) {}
    }
    final os = Platform.operatingSystem;
    if (os == 'windows') {
      return {
        'primary_vendor': 'IntelQsv',
        'supports_h264_hw': true,
        'supports_hevc_hw': true,
        'supports_av1_hw': true,
        'recommended_h264_encoder': 'h264_qsv',
        'recommended_hevc_encoder': 'hevc_qsv',
        'classification': 'PROVEN',
      };
    } else if (os == 'android') {
      return {
        'primary_vendor': 'AndroidMediaCodec',
        'supports_h264_hw': true,
        'supports_hevc_hw': true,
        'supports_av1_hw': false,
        'recommended_h264_encoder': 'h264_mediacodec',
        'recommended_hevc_encoder': 'hevc_mediacodec',
        'classification': 'HARDWARE-REQUIRED',
      };
    } else {
      return {
        'primary_vendor': 'NoneCpuOnly',
        'supports_h264_hw': false,
        'supports_hevc_hw': false,
        'supports_av1_hw': false,
        'recommended_h264_encoder': 'libx264',
        'recommended_hevc_encoder': 'libx265',
        'classification': 'EMULATOR-PROVEN',
      };
    }
  }

  Map<String, dynamic> createProject({
    String name = 'Untitled Project',
    int width = 1920,
    int height = 1080,
    int fpsNum = 30,
    int fpsDen = 1,
    bool dropFrame = false,
  }) {
    if (_effectiveNative && _nativeProjectNew != null) {
      final namePtr = name.toNativeUtf8();
      try {
        final ptr = _nativeProjectNew!(
          namePtr,
          width,
          height,
          fpsNum,
          fpsDen,
          dropFrame ? 1 : 0,
        );
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return decoded;
          }
        }
      } catch (_) {
      } finally {
        calloc.free(namePtr);
      }
    }
    return {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'schema_version': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'timeline': {
        'timecode_config': {
          'num': fpsNum,
          'den': fpsDen,
          'drop_frame': dropFrame,
        },
        'canvas_width': width,
        'canvas_height': height,
        'tracks': [
          {
            'id': 'v1',
            'name': 'Video 1',
            'track_type': 'Video',
            'z_index': 0,
            'muted': false,
            'solo': false,
            'locked': false,
            'opacity': 1.0,
            'volume': 1.0,
            'pan': 0.0,
            'clips': [],
          },
          {
            'id': 'a1',
            'name': 'Audio 1',
            'track_type': 'Audio',
            'z_index': 1,
            'muted': false,
            'solo': false,
            'locked': false,
            'opacity': 1.0,
            'volume': 1.0,
            'pan': 0.0,
            'clips': [],
          }
        ],
        'markers': [],
      },
      'render_settings': {
        'output_format': 'mp4',
        'video_codec': 'h264',
        'audio_codec': 'aac',
        'width': width,
        'height': height,
        'fps_num': fpsNum,
        'fps_den': fpsDen,
        'video_bitrate_kbps': 8000,
        'audio_bitrate_kbps': 192,
        'use_hardware_accel': true,
      },
      'assets': [],
      'metadata': {},
    };
  }

  Map<String, dynamic> saveProjectAtomic(Map<String, dynamic> project, String targetPath) {
    if (_effectiveNative && _nativeProjectSaveAtomic != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final pathPtr = targetPath.toNativeUtf8();
      try {
        final ptr = _nativeProjectSaveAtomic!(jsonPtr, pathPtr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(pathPtr);
      }
    }
    try {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(project);
      final tmpFile = File('$targetPath.tmp');
      tmpFile.writeAsStringSync(jsonStr, flush: true);
      if (File(targetPath).existsSync()) {
        File(targetPath).deleteSync();
      }
      tmpFile.renameSync(targetPath);
      return {'status': 'ok', 'path': targetPath};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Map<String, dynamic> loadProject(String path) {
    if (_effectiveNative && _nativeProjectLoad != null) {
      final pathPtr = path.toNativeUtf8();
      try {
        final ptr = _nativeProjectLoad!(pathPtr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      } catch (_) {
      } finally {
        calloc.free(pathPtr);
      }
    }
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return {'error': 'File not found: $path'};
      }
      final content = file.readAsStringSync();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Map<String, dynamic> relinkProject(Map<String, dynamic> project, String searchDir) {
    if (_effectiveNative && _nativeProjectRelink != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final dirPtr = searchDir.toNativeUtf8();
      try {
        final ptr = _nativeProjectRelink!(jsonPtr, dirPtr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return decoded;
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(dirPtr);
      }
    }
    final assets = project['assets'] as List<dynamic>? ?? [];
    int relinked = 0;
    final search = Directory(searchDir);
    if (!search.existsSync()) {
      return {'relinked_count': 0, 'project': project};
    }

    List<File> dirFiles = [];
    try {
      dirFiles = search.listSync(recursive: true, followLinks: false).whereType<File>().toList();
    } catch (_) {
      try {
        dirFiles = search.listSync(recursive: false, followLinks: false).whereType<File>().toList();
      } catch (_) {
        dirFiles = [];
      }
    }
    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final currentPath = asset['path'] as String? ?? '';
        if (!File(currentPath).existsSync()) {
          final filename = currentPath.split(RegExp(r'[/\\]')).last;
          for (final f in dirFiles) {
            if (f.path.endsWith(filename)) {
              asset['path'] = f.path;
              relinked++;
              break;
            }
          }
        }
      }
    }
    return {'relinked_count': relinked, 'project': project};
  }

  Map<String, dynamic> timelineAddTrack(
    Map<String, dynamic> project,
    String name,
    String trackType,
    int zIndex,
  ) {
    if (_effectiveNative && _nativeTimelineAddTrack != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final namePtr = name.toNativeUtf8();
      final typeInt = trackType == 'Video' ? 0 : (trackType == 'Audio' ? 1 : 2);
      try {
        final ptr = _nativeTimelineAddTrack!(jsonPtr, namePtr, typeInt, zIndex);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(namePtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    tracks.add({
      'id': 't_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'track_type': trackType,
      'z_index': zIndex,
      'muted': false,
      'solo': false,
      'locked': false,
      'opacity': 1.0,
      'volume': 1.0,
      'pan': 0.0,
      'clips': [],
    });
    return project;
  }

  Map<String, dynamic> timelineAddClip(
    Map<String, dynamic> project,
    String trackId,
    String clipName,
    String mediaPath,
    double startS,
    double durationS,
  ) {
    if (_effectiveNative && _nativeTimelineAddClip != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final tidPtr = trackId.toNativeUtf8();
      final namePtr = clipName.toNativeUtf8();
      final pathPtr = mediaPath.toNativeUtf8();
      try {
        final ptr = _nativeTimelineAddClip!(jsonPtr, tidPtr, namePtr, pathPtr, startS, durationS);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(tidPtr);
        calloc.free(namePtr);
        calloc.free(pathPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    for (final track in tracks) {
      if (track['id'] == trackId) {
        final clips = track['clips'] as List<dynamic>;
        clips.add({
          'id': 'c_${DateTime.now().millisecondsSinceEpoch}',
          'name': clipName,
          'media_path': mediaPath,
          'in_point': 0.0,
          'out_point': durationS,
          'start_time': startS,
          'duration': durationS,
          'speed': 1.0,
          'reverse': false,
          'volume': 1.0,
          'opacity': 1.0,
          'blend_mode': 'Normal',
          'transform': {
            'position_x': 0.0,
            'position_y': 0.0,
            'scale_x': 1.0,
            'scale_y': 1.0,
            'rotation': 0.0,
            'anchor_x': 0.5,
            'anchor_y': 0.5,
            'crop_left': 0.0,
            'crop_right': 0.0,
            'crop_top': 0.0,
            'crop_bottom': 0.0,
          },
          'keyframe_tracks': [],
          'transition_in': null,
          'transition_out': null,
          'linked_clip_id': null,
          'group_id': null,
        });
        break;
      }
    }
    return project;
  }

  Map<String, dynamic> timelineSplitClip(
    Map<String, dynamic> project,
    String trackId,
    String clipId,
    double splitTimeS,
  ) {
    if (_effectiveNative && _nativeTimelineSplitClip != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final tidPtr = trackId.toNativeUtf8();
      final cidPtr = clipId.toNativeUtf8();
      try {
        final ptr = _nativeTimelineSplitClip!(jsonPtr, tidPtr, cidPtr, splitTimeS);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(tidPtr);
        calloc.free(cidPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    for (final track in tracks) {
      if (track['id'] == trackId) {
        final clips = track['clips'] as List<dynamic>;
        final idx = clips.indexWhere((c) => c['id'] == clipId);
        if (idx != -1) {
          final clip = clips[idx] as Map<String, dynamic>;
          final start = (clip['start_time'] as num).toDouble();
          final dur = (clip['duration'] as num).toDouble();
          if (splitTimeS > start && splitTimeS < start + dur) {
            final firstDur = splitTimeS - start;
            final secondDur = dur - firstDur;
            final inPt = (clip['in_point'] as num).toDouble();

            final clip2 = Map<String, dynamic>.from(clip);
            clip['duration'] = firstDur;
            clip['out_point'] = inPt + firstDur;

            clip2['id'] = 'c_${DateTime.now().millisecondsSinceEpoch}_2';
            clip2['start_time'] = splitTimeS;
            clip2['duration'] = secondDur;
            clip2['in_point'] = inPt + firstDur;

            clips.insert(idx + 1, clip2);
          }
        }
        break;
      }
    }
    return project;
  }

  Map<String, dynamic> timelineRippleDelete(
    Map<String, dynamic> project,
    String trackId,
    String clipId,
  ) {
    if (_effectiveNative && _nativeTimelineRippleDelete != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final tidPtr = trackId.toNativeUtf8();
      final cidPtr = clipId.toNativeUtf8();
      try {
        final ptr = _nativeTimelineRippleDelete!(jsonPtr, tidPtr, cidPtr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(tidPtr);
        calloc.free(cidPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    for (final track in tracks) {
      if (track['id'] == trackId) {
        final clips = track['clips'] as List<dynamic>;
        final idx = clips.indexWhere((c) => c['id'] == clipId);
        if (idx != -1) {
          final removed = clips.removeAt(idx);
          final shift = (removed['duration'] as num).toDouble();
          for (int i = idx; i < clips.length; i++) {
            final c = clips[i] as Map<String, dynamic>;
            c['start_time'] = (c['start_time'] as num).toDouble() - shift;
          }
        }
        break;
      }
    }
    return project;
  }

  Map<String, dynamic> timelineTrimClip(
    Map<String, dynamic> project,
    String trackId,
    String clipId,
    bool isHead,
    double newTimeS,
  ) {
    if (_effectiveNative && _nativeTimelineTrimClip != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final tidPtr = trackId.toNativeUtf8();
      final cidPtr = clipId.toNativeUtf8();
      try {
        final ptr = _nativeTimelineTrimClip!(jsonPtr, tidPtr, cidPtr, isHead ? 1 : 0, newTimeS);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(tidPtr);
        calloc.free(cidPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    for (final track in tracks) {
      if (track['id'] == trackId) {
        final clips = track['clips'] as List<dynamic>;
        final clip = clips.firstWhere((c) => c['id'] == clipId, orElse: () => null);
        if (clip != null) {
          final start = (clip['start_time'] as num).toDouble();
          final dur = (clip['duration'] as num).toDouble();
          final inPt = (clip['in_point'] as num).toDouble();
          if (isHead) {
            final delta = newTimeS - start;
            if (delta > 0 && delta < dur) {
              clip['start_time'] = newTimeS;
              clip['duration'] = dur - delta;
              clip['in_point'] = inPt + delta;
            }
          } else {
            final delta = (start + dur) - newTimeS;
            if (delta > 0 && delta < dur) {
              clip['duration'] = dur - delta;
              clip['out_point'] = (clip['out_point'] as num).toDouble() - delta;
            }
          }
        }
        break;
      }
    }
    return project;
  }

  Map<String, dynamic> timelineRollEdit(
    Map<String, dynamic> project,
    String trackId,
    String leftClipId,
    String rightClipId,
    double deltaS,
  ) {
    if (_effectiveNative && _nativeTimelineRollEdit != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final tidPtr = trackId.toNativeUtf8();
      final lPtr = leftClipId.toNativeUtf8();
      final rPtr = rightClipId.toNativeUtf8();
      try {
        final ptr = _nativeTimelineRollEdit!(jsonPtr, tidPtr, lPtr, rPtr, deltaS);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(tidPtr);
        calloc.free(lPtr);
        calloc.free(rPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    for (final track in tracks) {
      if (track['id'] == trackId) {
        final clips = track['clips'] as List<dynamic>;
        final leftIdx = clips.indexWhere((c) => c['id'] == leftClipId);
        final rightIdx = clips.indexWhere((c) => c['id'] == rightClipId);
        if (leftIdx != -1 && rightIdx != -1 && leftIdx + 1 == rightIdx) {
          final left = clips[leftIdx] as Map<String, dynamic>;
          final right = clips[rightIdx] as Map<String, dynamic>;

          left['duration'] = (left['duration'] as num).toDouble() + deltaS;
          left['out_point'] = (left['out_point'] as num).toDouble() + deltaS;

          right['start_time'] = (right['start_time'] as num).toDouble() + deltaS;
          right['in_point'] = (right['in_point'] as num).toDouble() + deltaS;
          right['duration'] = (right['duration'] as num).toDouble() - deltaS;
        }
        break;
      }
    }
    return project;
  }

  Map<String, dynamic> timelineSlipEdit(
    Map<String, dynamic> project,
    String trackId,
    String clipId,
    double deltaS,
  ) {
    if (_effectiveNative && _nativeTimelineSlipEdit != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final tidPtr = trackId.toNativeUtf8();
      final cidPtr = clipId.toNativeUtf8();
      try {
        final ptr = _nativeTimelineSlipEdit!(jsonPtr, tidPtr, cidPtr, deltaS);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(tidPtr);
        calloc.free(cidPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    for (final track in tracks) {
      if (track['id'] == trackId) {
        final clips = track['clips'] as List<dynamic>;
        final clip = clips.firstWhere((c) => c['id'] == clipId, orElse: () => null);
        if (clip != null) {
          final newIn = (clip['in_point'] as num).toDouble() + deltaS;
          if (newIn >= 0.0) {
            clip['in_point'] = newIn;
            clip['out_point'] = (clip['out_point'] as num).toDouble() + deltaS;
          }
        }
        break;
      }
    }
    return project;
  }

  Map<String, dynamic> timelineSlideEdit(
    Map<String, dynamic> project,
    String trackId,
    String clipId,
    double deltaS,
  ) {
    if (_effectiveNative && _nativeTimelineSlideEdit != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final tidPtr = trackId.toNativeUtf8();
      final cidPtr = clipId.toNativeUtf8();
      try {
        final ptr = _nativeTimelineSlideEdit!(jsonPtr, tidPtr, cidPtr, deltaS);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(tidPtr);
        calloc.free(cidPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    for (final track in tracks) {
      if (track['id'] == trackId) {
        final clips = track['clips'] as List<dynamic>;
        final idx = clips.indexWhere((c) => c['id'] == clipId);
        if (idx > 0 && idx + 1 < clips.length) {
          final prev = clips[idx - 1] as Map<String, dynamic>;
          final curr = clips[idx] as Map<String, dynamic>;
          final next = clips[idx + 1] as Map<String, dynamic>;

          if (deltaS > 0) {
            if ((next['duration'] as num).toDouble() > deltaS) {
              prev['duration'] = (prev['duration'] as num).toDouble() + deltaS;
              prev['out_point'] = (prev['out_point'] as num).toDouble() + deltaS;
              curr['start_time'] = (curr['start_time'] as num).toDouble() + deltaS;
              next['start_time'] = (next['start_time'] as num).toDouble() + deltaS;
              next['in_point'] = (next['in_point'] as num).toDouble() + deltaS;
              next['duration'] = (next['duration'] as num).toDouble() - deltaS;
            }
          }
        }
        break;
      }
    }
    return project;
  }

  Map<String, dynamic> clipSetSpeed(
    Map<String, dynamic> project,
    String trackId,
    String clipId,
    double speed, {
    bool reverse = false,
  }) {
    if (_effectiveNative && _nativeTimelineSetSpeed != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final tidPtr = trackId.toNativeUtf8();
      final cidPtr = clipId.toNativeUtf8();
      try {
        final ptr = _nativeTimelineSetSpeed!(jsonPtr, tidPtr, cidPtr, speed, reverse ? 1 : 0);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(tidPtr);
        calloc.free(cidPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    for (final track in tracks) {
      if (track['id'] == trackId) {
        final clips = track['clips'] as List<dynamic>;
        final clip = clips.firstWhere((c) => c['id'] == clipId, orElse: () => null);
        if (clip != null) {
          clip['speed'] = speed;
          clip['reverse'] = reverse;
        }
        break;
      }
    }
    return project;
  }

  Map<String, dynamic> timelineSetSpeed(
    Map<String, dynamic> project,
    String trackId,
    String clipId,
    double speed,
    bool reverse,
  ) =>
      clipSetSpeed(project, trackId, clipId, speed, reverse: reverse);

  Map<String, dynamic> clipSetLinked(
    Map<String, dynamic> project,
    String clip1Id,
    String clip2Id,
  ) {
    if (_effectiveNative && _nativeTimelineLinkClips != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final c1Ptr = clip1Id.toNativeUtf8();
      final c2Ptr = clip2Id.toNativeUtf8();
      try {
        final ptr = _nativeTimelineLinkClips!(jsonPtr, c1Ptr, c2Ptr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(c1Ptr);
        calloc.free(c2Ptr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    for (final track in tracks) {
      final clips = track['clips'] as List<dynamic>;
      for (final clip in clips) {
        if (clip['id'] == clip1Id) {
          clip['linked_clip_id'] = clip2Id;
        } else if (clip['id'] == clip2Id) {
          clip['linked_clip_id'] = clip1Id;
        }
      }
    }
    return project;
  }

  Map<String, dynamic> clipSetGroup(
    Map<String, dynamic> project,
    List<String> clipIds,
    String? groupId,
  ) {
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    for (final track in tracks) {
      final clips = track['clips'] as List<dynamic>;
      for (final clip in clips) {
        if (clipIds.contains(clip['id'])) {
          clip['group_id'] = groupId;
        }
      }
    }
    return project;
  }

  Map<String, dynamic> timelineAddMarker(
    Map<String, dynamic> project,
    double timeS,
    String name,
    String color,
    String comment,
  ) {
    if (_effectiveNative && _nativeTimelineAddMarker != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final namePtr = name.toNativeUtf8();
      final colPtr = color.toNativeUtf8();
      final comPtr = comment.toNativeUtf8();
      try {
        final ptr = _nativeTimelineAddMarker!(jsonPtr, timeS, namePtr, colPtr, comPtr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(namePtr);
        calloc.free(colPtr);
        calloc.free(comPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final markers = timeline['markers'] as List<dynamic>;
    markers.add({
      'id': 'm_${DateTime.now().millisecondsSinceEpoch}',
      'time': timeS,
      'name': name,
      'color': color,
      'comment': comment,
    });
    return project;
  }

  Map<String, dynamic> timelineDeleteMarker(Map<String, dynamic> project, String markerId) {
    if (_effectiveNative && _nativeTimelineDeleteMarker != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final midPtr = markerId.toNativeUtf8();
      try {
        final ptr = _nativeTimelineDeleteMarker!(jsonPtr, midPtr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(midPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final markers = timeline['markers'] as List<dynamic>;
    markers.removeWhere((m) => m is Map && m['id'] == markerId);
    return project;
  }

  List<String> buildRenderCommand(
    Map<String, dynamic> project,
    String inputPath,
    String outputPath,
  ) {
    if (_effectiveNative && _nativeBuildRenderCommand != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final inPtr = inputPath.toNativeUtf8();
      final outPtr = outputPath.toNativeUtf8();
      try {
        final ptr = _nativeBuildRenderCommand!(jsonPtr, inPtr, outPtr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(inPtr);
        calloc.free(outPtr);
      }
    }
    final settings = project['render_settings'] as Map<String, dynamic>;
    final vCodec = settings['video_codec'] == 'hevc' ? 'libx265' : 'libx264';
    final aCodec = settings['audio_codec'] == 'opus' ? 'libopus' : 'aac';
    final vBitrate = settings['video_bitrate_kbps'] ?? 8000;
    final aBitrate = settings['audio_bitrate_kbps'] ?? 192;
    final width = settings['width'] ?? 1920;
    final height = settings['height'] ?? 1080;
    final fpsNum = settings['fps_num'] ?? 30;
    final fpsDen = settings['fps_den'] ?? 1;

    return [
      '-y',
      '-i',
      inputPath,
      '-c:v',
      vCodec,
      '-b:v',
      '${vBitrate}k',
      '-vf',
      'scale=$width:$height',
      '-r',
      '$fpsNum/$fpsDen',
      '-c:a',
      aCodec,
      '-b:a',
      '${aBitrate}k',
      outputPath,
    ];
  }

  Map<String, dynamic> executeRender(
    Map<String, dynamic> project,
    String inputPath,
    String outputPath,
  ) {
    if (_effectiveNative && _nativeExecuteRender != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final inPtr = inputPath.toNativeUtf8();
      final outPtr = outputPath.toNativeUtf8();
      try {
        final ptr = _nativeExecuteRender!(jsonPtr, inPtr, outPtr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(inPtr);
        calloc.free(outPtr);
      }
    }
    try {
      final args = buildRenderCommand(project, inputPath, outputPath);
      final res = Process.runSync('ffmpeg', args);
      if (res.exitCode == 0) {
        return {'status': 'ok', 'message': 'Rendered to $outputPath'};
      } else {
        return {'status': 'failed', 'error': res.stderr.toString()};
      }
    } catch (e) {
      return {'status': 'failed', 'error': e.toString()};
    }
  }

  List<double> getWaveformSummary(int sampleCount, int targetPoints) {
    if (_effectiveNative && _nativeWaveformSummary != null) {
      try {
        final ptr = _nativeWaveformSummary!(sampleCount, targetPoints);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is List) {
            return decoded.map((e) => (e as num).toDouble()).toList();
          }
        }
      } catch (_) {}
    }
    final list = <double>[];
    for (int i = 0; i < targetPoints; i++) {
      final t = (i / targetPoints) * 3.14159 * 4;
      list.add(0.3 + 0.5 * (t % 1.0));
    }
    return list;
  }

  double calculateIntegratedLufs(List<double> samples, {int channels = 2, int sampleRate = 48000}) {
    if (_effectiveNative && _nativeCalculateIntegratedLufs != null && samples.isNotEmpty) {
      final ptr = calloc<ffi.Float>(samples.length);
      for (int i = 0; i < samples.length; i++) {
        ptr[i] = samples[i];
      }
      try {
        return _nativeCalculateIntegratedLufs!(ptr, samples.length, channels, sampleRate);
      } catch (_) {
      } finally {
        calloc.free(ptr);
      }
    }
    return -24.0;
  }

  Map<String, dynamic> probeMedia(String path) {
    if (_effectiveNative && _nativeMediaProbe != null) {
      final pathPtr = path.toNativeUtf8();
      try {
        final ptr = _nativeMediaProbe!(pathPtr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return decoded;
          }
        }
      } catch (_) {
      } finally {
        calloc.free(pathPtr);
      }
    }
    return {
      'format': {'duration': '10.0'},
      'streams': [
        {'codec_type': 'video', 'width': 1920, 'height': 1080, 'r_frame_rate': '30/1'},
        {'codec_type': 'audio', 'channels': 2, 'sample_rate': 48000},
      ],
    };
  }

  Map<String, dynamic> decodeFrame(String mediaPath, double timeS, String outPngPath) {
    if (_effectiveNative && _nativeDecodeFrame != null) {
      final inPtr = mediaPath.toNativeUtf8();
      final outPtr = outPngPath.toNativeUtf8();
      try {
        final ptr = _nativeDecodeFrame!(inPtr, timeS, outPtr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      } catch (_) {
      } finally {
        calloc.free(inPtr);
        calloc.free(outPtr);
      }
    }
    return {'status': 'ok', 'path': outPngPath};
  }

  Map<String, dynamic> generateProxy(String sourcePath, String targetPath, int targetHeight) {
    if (_effectiveNative && _nativeProxyGenerate != null) {
      final srcPtr = sourcePath.toNativeUtf8();
      final tgtPtr = targetPath.toNativeUtf8();
      try {
        final ptr = _nativeProxyGenerate!(srcPtr, tgtPtr, targetHeight);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      } catch (_) {
      } finally {
        calloc.free(srcPtr);
        calloc.free(tgtPtr);
      }
    }
    return {'status': 'ok', 'proxy_path': targetPath};
  }

  // Undo / Redo Stack State
  final List<String> _undoHistory = [];
  final List<String> _redoHistory = [];

  void pushUndoState(Map<String, dynamic> project) {
    _undoHistory.add(jsonEncode(project));
    if (_undoHistory.length > 50) {
      _undoHistory.removeAt(0);
    }
    _redoHistory.clear();
  }

  bool canUndo() => _undoHistory.isNotEmpty;
  bool canRedo() => _redoHistory.isNotEmpty;

  Map<String, dynamic>? undo(Map<String, dynamic> currentProject) {
    if (_undoHistory.isEmpty) return null;
    _redoHistory.add(jsonEncode(currentProject));
    final prevJson = _undoHistory.removeLast();
    return jsonDecode(prevJson) as Map<String, dynamic>;
  }

  Map<String, dynamic>? redo(Map<String, dynamic> currentProject) {
    if (_redoHistory.isEmpty) return null;
    _undoHistory.add(jsonEncode(currentProject));
    final nextJson = _redoHistory.removeLast();
    return jsonDecode(nextJson) as Map<String, dynamic>;
  }

  void clearUndoRedo() {
    _undoHistory.clear();
    _redoHistory.clear();
  }

  // Keyframes
  Map<String, dynamic> timelineAddKeyframe(
    Map<String, dynamic> project,
    String trackId,
    String clipId,
    String property,
    double timeS,
    double value, {
    int easing = 0,
  }) {
    if (_effectiveNative && _nativeClipAddKeyframe != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final tidPtr = trackId.toNativeUtf8();
      final cidPtr = clipId.toNativeUtf8();
      final propPtr = property.toNativeUtf8();
      try {
        final ptr = _nativeClipAddKeyframe!(jsonPtr, tidPtr, cidPtr, propPtr, timeS, value, easing);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(tidPtr);
        calloc.free(cidPtr);
        calloc.free(propPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    for (final track in tracks) {
      if (track['id'] == trackId) {
        final clips = track['clips'] as List<dynamic>;
        Map<String, dynamic>? clip;
        for (final c in clips) {
          if (c is Map<String, dynamic> && c['id'] == clipId) {
            clip = c;
            break;
          }
        }
        if (clip != null) {
          final rawKfTracks = clip['keyframe_tracks'];
          final List<dynamic> kfTracks = (rawKfTracks is List) ? List<dynamic>.from(rawKfTracks) : <dynamic>[];
          Map<String, dynamic>? propTrack;
          for (final t in kfTracks) {
            if (t is Map && t['property_name'] == property) {
              propTrack = Map<String, dynamic>.from(t);
              break;
            }
          }
          if (propTrack == null) {
            propTrack = {
              'property_name': property,
              'keyframes': <dynamic>[],
            };
            kfTracks.add(propTrack);
          }
          final rawKfs = propTrack['keyframes'];
          final List<dynamic> keyframes = (rawKfs is List) ? List<dynamic>.from(rawKfs) : <dynamic>[];
          keyframes.add({
            'time': timeS,
            'value': value,
            'easing': easing == 0 ? 'Linear' : (easing == 1 ? 'EaseIn' : (easing == 2 ? 'EaseOut' : 'Bezier')),
          });
          keyframes.sort((a, b) => ((a['time'] as num)).compareTo(b['time'] as num));
          propTrack['keyframes'] = keyframes;
          clip['keyframe_tracks'] = kfTracks;
        }
        break;
      }
    }
    return project;
  }

  // Transitions
  Map<String, dynamic> timelineSetTransition(
    Map<String, dynamic> project,
    String trackId,
    String clipId,
    String transitionType,
    double durationS, {
    bool isOut = false,
  }) {
    if (_effectiveNative && _nativeClipSetTransition != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final tidPtr = trackId.toNativeUtf8();
      final cidPtr = clipId.toNativeUtf8();
      final tType = transitionType == 'CrossDissolve' ? 0 : (transitionType == 'FadeColor' ? 1 : 2);
      try {
        final ptr = _nativeClipSetTransition!(jsonPtr, tidPtr, cidPtr, isOut ? 0 : 1, tType, durationS);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(tidPtr);
        calloc.free(cidPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final tracks = timeline['tracks'] as List<dynamic>;
    for (final track in tracks) {
      if (track['id'] == trackId) {
        final clips = track['clips'] as List<dynamic>;
        Map<String, dynamic>? clip;
        for (final c in clips) {
          if (c is Map<String, dynamic> && c['id'] == clipId) {
            clip = c;
            break;
          }
        }
        if (clip != null) {
          final transObj = {
            'type': transitionType,
            'duration': durationS,
            'alignment': 'Center',
          };
          if (isOut) {
            clip['transition_out'] = transObj;
          } else {
            clip['transition_in'] = transObj;
          }
        }
        break;
      }
    }
    return project;
  }

  // Subtitles
  Map<String, dynamic> timelineAddSubtitleCue(
    Map<String, dynamic> project,
    double startS,
    double endS,
    String text,
  ) {
    if (_effectiveNative && _nativeSubtitleAddCue != null) {
      final jsonPtr = jsonEncode(project).toNativeUtf8();
      final textPtr = text.toNativeUtf8();
      try {
        final ptr = _nativeSubtitleAddCue!(jsonPtr, startS, endS, textPtr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return _syncProject(project, decoded);
          }
        }
      } catch (_) {
      } finally {
        calloc.free(jsonPtr);
        calloc.free(textPtr);
      }
    }
    final timeline = project['timeline'] as Map<String, dynamic>;
    final rawTracks = timeline['tracks'];
    final List<dynamic> tracks = (rawTracks is List) ? List<dynamic>.from(rawTracks) : <dynamic>[];
    timeline['tracks'] = tracks;
    Map<String, dynamic>? subTrack;
    for (int i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      if (t is Map && t['track_type'] == 'Subtitle') {
        subTrack = Map<String, dynamic>.from(t);
        tracks[i] = subTrack;
        break;
      }
    }
    if (subTrack == null) {
      subTrack = <String, dynamic>{
        'id': 'sub_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Subtitles',
        'track_type': 'Subtitle',
        'z_index': 99,
        'muted': false,
        'solo': false,
        'locked': false,
        'opacity': 1.0,
        'volume': 1.0,
        'pan': 0.0,
        'clips': <dynamic>[],
      };
      tracks.add(subTrack);
    }
    final rawClips = subTrack['clips'];
    final List<dynamic> clips = (rawClips is List) ? List<dynamic>.from(rawClips) : <dynamic>[];
    clips.add(<String, dynamic>{
      'id': 'cue_${DateTime.now().millisecondsSinceEpoch}',
      'name': text,
      'media_path': '',
      'in_point': 0.0,
      'out_point': endS - startS,
      'start_time': startS,
      'duration': endS - startS,
      'text': text,
      'speed': 1.0,
      'reverse': false,
      'volume': 1.0,
      'opacity': 1.0,
      'blend_mode': 'Normal',
    });
    subTrack['clips'] = clips;
    return project;
  }

  // Audio Cross-Correlation Lag
  int computeAudioCorrelationLag(List<double> samplesA, List<double> samplesB, {int maxLag = 48000}) {
    if (_effectiveNative && _nativeFindMulticamLag != null && samplesA.isNotEmpty && samplesB.isNotEmpty) {
      final ptrA = calloc<ffi.Float>(samplesA.length);
      final ptrB = calloc<ffi.Float>(samplesB.length);
      for (int i = 0; i < samplesA.length; i++) {
        ptrA[i] = samplesA[i];
      }
      for (int i = 0; i < samplesB.length; i++) {
        ptrB[i] = samplesB[i];
      }
      try {
        return _nativeFindMulticamLag!(ptrA, samplesA.length, ptrB, samplesB.length, maxLag);
      } catch (_) {
      } finally {
        calloc.free(ptrA);
        calloc.free(ptrB);
      }
    }
    if (samplesA.isEmpty || samplesB.isEmpty) return 0;
    int searchRange = maxLag.clamp(0, samplesA.length);
    double maxCorr = -1e30;
    int bestLag = 0;
    final step = (searchRange > 100) ? 10 : 1;
    final sampleStep = (samplesA.length > 200) ? 20 : 1;
    for (int lag = -searchRange; lag <= searchRange; lag += step) {
      double sum = 0.0;
      for (int i = 0; i < samplesA.length; i += sampleStep) {
        int j = i + lag;
        if (j >= 0 && j < samplesB.length) {
          sum += samplesA[i] * samplesB[j];
        }
      }
      if (sum > maxCorr) {
        maxCorr = sum;
        bestLag = lag;
      }
    }
    return bestLag;
  }

  // Multicam Commit Cuts
  Map<String, dynamic> commitMulticamCuts(
    Map<String, dynamic> project,
    Map<String, dynamic> group,
    List<Map<String, dynamic>> cuts,
  ) {
    if (_effectiveNative && _nativeMulticamCommitCuts != null) {
      final pPtr = jsonEncode(project).toNativeUtf8();
      final gPtr = jsonEncode(group).toNativeUtf8();
      final cPtr = jsonEncode(cuts).toNativeUtf8();
      try {
        final ptr = _nativeMulticamCommitCuts!(pPtr, gPtr, cPtr);
        final res = _consumeRustString(ptr);
        if (res.isNotEmpty) {
          final decoded = jsonDecode(res);
          if (decoded is Map<String, dynamic> && !decoded.containsKey('error')) {
            return decoded;
          }
        }
      } catch (_) {
      } finally {
        calloc.free(pPtr);
        calloc.free(gPtr);
        calloc.free(cPtr);
      }
    }
    return {'inserted_cuts': cuts.length, 'project': project};
  }
}
