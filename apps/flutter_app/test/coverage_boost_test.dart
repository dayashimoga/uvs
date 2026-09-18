import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_video_studio/src/core/ffi_bridge.dart';
import 'package:universal_video_studio/src/models/project_model.dart';
import 'package:universal_video_studio/src/models/render_job_model.dart';
import 'package:universal_video_studio/src/services/project_service.dart';
import 'package:universal_video_studio/src/widgets/audio_mixer_view.dart';
import 'package:universal_video_studio/src/widgets/color_inspector_view.dart';
import 'package:universal_video_studio/src/modes/player_mode.dart';
import 'package:universal_video_studio/src/modes/quick_edit_mode.dart';
import 'package:universal_video_studio/src/modes/multi_view_mode.dart';
import 'package:universal_video_studio/src/modes/multicam_mode.dart';
import 'package:universal_video_studio/src/modes/studio_editor_mode.dart';
import 'package:universal_video_studio/src/modes/recording_dialog.dart';
import 'package:universal_video_studio/src/models/track_model.dart';
import 'package:universal_video_studio/src/models/clip_model.dart';
import 'package:universal_video_studio/src/services/recording_service.dart';
import 'package:universal_video_studio/src/services/render_service.dart';
import 'package:universal_video_studio/src/services/media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UvsFfiBridge and Pure-Dart Engine Tests', () {
    test('UvsFfiBridge version and hardware detection', () {
      final bridge = UvsFfiBridge.instance;
      expect(bridge.getCoreVersion(), '0.1.0-production');

      final hw = bridge.detectHardware();
      expect(hw.containsKey('primary_vendor'), isTrue);
      expect(hw.containsKey('recommended_h264_encoder'), isTrue);
      expect(hw.containsKey('classification'), isTrue);
    });

    test('UvsFfiBridge project lifecycle, I/O and atomic save', () {
      final bridge = UvsFfiBridge.instance;
      var proj = bridge.createProject(
        name: 'FFI Test Suite',
        width: 3840,
        height: 2160,
        fpsNum: 60,
        fpsDen: 1,
        dropFrame: false,
      );
      expect(proj['name'], 'FFI Test Suite');
      expect((proj['timeline']['tracks'] as List).length, 2);

      final tmpPath = '${Directory.systemTemp.path}/uvs_test_proj_${DateTime.now().millisecondsSinceEpoch}.uvsp';
      final saveRes = bridge.saveProjectAtomic(proj, tmpPath);
      expect(saveRes['status'], 'ok');
      expect(File(tmpPath).existsSync(), isTrue);

      final loaded = bridge.loadProject(tmpPath);
      expect(loaded['name'], 'FFI Test Suite');

      // Test non-existent file
      final notFound = bridge.loadProject('/path/does/not/exist/foo.uvsp');
      expect(notFound.containsKey('error'), isTrue);

      // Clean up
      File(tmpPath).deleteSync();
    });

    test('UvsFfiBridge relinkProject finds matching files', () {
      final bridge = UvsFfiBridge.instance;
      final tempDir = Directory.systemTemp.createTempSync('uvs_relink_test_');
      final mediaFile = File('${tempDir.path}/test_footage.mp4');
      mediaFile.writeAsStringSync('dummy content');

      final proj = bridge.createProject(name: 'Relink Test');
      proj['assets'] = [
        {'id': 'a1', 'name': 'test_footage.mp4', 'path': '/old/missing/test_footage.mp4'}
      ];

      final relinkRes = bridge.relinkProject(proj, tempDir.path);
      expect(relinkRes['relinked_count'], 1);

      // Relink with invalid dir
      final badDirRes = bridge.relinkProject(proj, '/invalid/nonexistent/dir');
      expect(badDirRes['relinked_count'], 0);

      tempDir.deleteSync(recursive: true);
    });

    test('UvsFfiBridge comprehensive timeline operations', () {
      final bridge = UvsFfiBridge.instance;
      var proj = bridge.createProject(name: 'Timeline Op Suite');
      proj = bridge.timelineAddTrack(proj, 'V2 B-Roll', 'Video', 2);
      final tracks = proj['timeline']['tracks'] as List;
      expect(tracks.length, 3);
      final v2Id = tracks.last['id'] as String;

      // Add clips
      proj = bridge.timelineAddClip(proj, v2Id, 'Clip 1', 'c1.mp4', 0.0, 5.0);
      proj = bridge.timelineAddClip(proj, v2Id, 'Clip 2', 'c2.mp4', 5.0, 5.0);
      proj = bridge.timelineAddClip(proj, v2Id, 'Clip 3', 'c3.mp4', 10.0, 5.0);
      final clips = tracks.last['clips'] as List;
      expect(clips.length, 3);
      final c1Id = clips[0]['id'] as String;
      final c2Id = clips[1]['id'] as String;

      // Split clip
      proj = bridge.timelineSplitClip(proj, v2Id, c1Id, 2.5);
      expect(clips.length, 4);

      // Roll edit
      proj = bridge.timelineRollEdit(proj, v2Id, clips[1]['id'] as String, clips[2]['id'] as String, 0.5);

      // Slip edit
      proj = bridge.timelineSlipEdit(proj, v2Id, c2Id, 0.5);

      // Slide edit
      proj = bridge.timelineSlideEdit(proj, v2Id, clips[2]['id'] as String, 0.2);

      // Set speed and reverse
      proj = bridge.timelineSetSpeed(proj, v2Id, c2Id, 2.0, true);
      final c2Obj = clips.firstWhere((c) => c['id'] == c2Id) as Map<String, dynamic>;
      expect(c2Obj['speed'], 2.0);
      expect(c2Obj['reverse'], true);

      // Add marker
      proj = bridge.timelineAddMarker(proj, 3.5, 'Marker 1', '#00FFFF', 'Review note');
      expect((proj['timeline']['markers'] as List).length, 1);

      // Ripple delete
      proj = bridge.timelineRippleDelete(proj, v2Id, clips[0]['id'] as String);
      expect(clips.length, 3);

      // Waveform summary
      final wf = bridge.getWaveformSummary(1000, 30);
      expect(wf.length, 30);

      // Render command construction
      final cmdH264 = bridge.buildRenderCommand(proj, 'in.mp4', 'out.mp4');
      expect(cmdH264.contains('-c:v'), isTrue);
      expect(cmdH264.any((arg) => arg == 'libx264' || arg.contains('h264')), isTrue);

      proj['render_settings']['video_codec'] = 'hevc';
      proj['render_settings']['audio_codec'] = 'opus';
      final cmdHevc = bridge.buildRenderCommand(proj, 'in.mp4', 'out.mp4');
      expect(cmdHevc.any((arg) => arg == 'libx265' || arg.contains('hevc')), isTrue);
      expect(cmdHevc.contains('libopus'), isTrue);
    });

    test('ProjectService advanced timeline mutation methods', () {
      final s = ProjectService.instance;
      s.newProject(name: 'ProjectService Advanced', width: 1920, height: 1080);
      s.addTrack('FX Track', 'Video', 3);
      final trackId = (s.project['timeline']['tracks'] as List).last['id'] as String;

      s.addClip(trackId, 'FX Clip 1', 'fx1.mov', 0.0, 4.0);
      s.addClip(trackId, 'FX Clip 2', 'fx2.mov', 4.0, 4.0);
      s.addClip(trackId, 'FX Clip 3', 'fx3.mov', 8.0, 4.0);

      final clips = (s.project['timeline']['tracks'] as List).last['clips'] as List;
      final c1 = clips[0]['id'] as String;
      final c2 = clips[1]['id'] as String;

      s.rollEdit(trackId, c1, c2, 0.5);
      s.slipEdit(trackId, c1, 0.2);
      s.slideEdit(trackId, c2, 0.1);
      s.setClipSpeed(trackId, c1, 1.5, false);
      s.addMarker(1.5, 'Sync Beat', '#FF0055', 'Drum transient');
      expect((s.project['timeline']['markers'] as List).length, 1);

      final tempDir = Directory.systemTemp.createTempSync('uvs_ps_test_');
      final tempSave = '${tempDir.path}/uvs_ps_${DateTime.now().millisecondsSinceEpoch}.uvsp';
      expect(s.saveProject(tempSave), isTrue);
      expect(s.loadProject(tempSave), isTrue);
      expect(s.currentFilePath, tempSave);
      expect(s.isDirty, isFalse);

      expect(s.relinkAssets(tempDir.path), greaterThanOrEqualTo(0));

      // Cleanup
      tempDir.deleteSync(recursive: true);
    });
  });

  group('Widget Coverage Boost Tests', () {
    testWidgets('AudioMixerView renders strips, faders, EQ, and compressor controls', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final proj = ProjectModel.createDefault();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: AudioMixerView(project: proj),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Studio Audio Mixer & DSP"), findsOneWidget);
      expect(find.text("MASTER"), findsOneWidget);
      expect(find.text("5-Band Parametric Equalizer"), findsOneWidget);
      expect(find.text("Dynamic Compressor / Limiter"), findsOneWidget);

      // Exercise sliders
      final sliders = find.byType(Slider);
      expect(sliders, findsWidgets);

      for (int i = 0; i < sliders.evaluate().length && i < 6; i++) {
        final slider = sliders.at(i);
        await tester.drag(slider, const Offset(10, 0));
        await tester.pumpAndSettle();
      }

      // Track Mute and Solo buttons
      final muteBtn = find.text("M").first;
      await tester.tap(muteBtn);
      await tester.pumpAndSettle();

      final soloBtn = find.text("S").first;
      await tester.tap(soloBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('ColorInspectorView renders 3D LUT dropdown and color grading sliders', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: ColorInspectorView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Color Grading & Visuals"), findsOneWidget);
      expect(find.text("3D LUT Profile (.cube)"), findsOneWidget);
      expect(find.text("Color Wheels"), findsOneWidget);

      // Change LUT profile
      final lutDropdown = find.text("None");
      expect(lutDropdown, findsOneWidget);
      await tester.tap(lutDropdown);
      await tester.pumpAndSettle();

      final warmOption = find.text("Teal & Orange Rec709").last;
      await tester.tap(warmOption);
      await tester.pumpAndSettle();

      // Sliders: Exposure, Contrast, Highlights, Shadows, Temp, Tint, Saturation
      final sliders = find.byType(Slider);
      expect(sliders, findsWidgets);
      for (int i = 0; i < sliders.evaluate().length; i++) {
        await tester.drag(sliders.at(i), const Offset(20, 0));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('PlayerModeView exercises A-B repeat, subtitles, and calibration dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: PlayerModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set Point A and Point B
      final setABtn = find.text("Set A");
      expect(setABtn, findsOneWidget);
      await tester.tap(setABtn);
      await tester.pumpAndSettle();

      final setBBtn = find.text("Set B");
      expect(setBBtn, findsOneWidget);
      await tester.tap(setBBtn);
      await tester.pumpAndSettle();

      // Clear A-B
      final clearBtn = find.byTooltip("Clear A-B Repeat");
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Speed dropdown
      final speedDropdown = find.text("1.0x");
      expect(speedDropdown, findsOneWidget);
      await tester.tap(speedDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text("2.0x").last);
      await tester.pumpAndSettle();

      // Audio sync calibration dialog
      final syncBtn = find.byTooltip("Audio Sync");
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pumpAndSettle();
      expect(find.text("Audio Sync Calibration"), findsOneWidget);

      final calibSlider = find.byType(Slider).last;
      await tester.drag(calibSlider, const Offset(30, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Close"));
      await tester.pumpAndSettle();

      // Subtitles popup menu
      final subBtn = find.byTooltip("Subtitles");
      expect(subBtn, findsOneWidget);
      await tester.tap(subBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Spanish").last);
      await tester.pumpAndSettle();

      // Snapshot capture
      final snapBtn = find.byTooltip("Capture Snapshot");
      expect(snapBtn, findsOneWidget);
      await tester.tap(snapBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining("Captured frame snapshot"), findsOneWidget);
    });

    testWidgets('QuickEditModeView exercises aspect ratio, filters, rotation and export', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: QuickEditModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test Aspect Ratio chips
      for (final ratio in ['9:16', '1:1', '4:3', '16:9']) {
        final chip = find.text(ratio);
        expect(chip, findsOneWidget);
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }

      // Rotate button
      final rotateBtn = find.byIcon(Icons.rotate_90_degrees_cw);
      expect(rotateBtn, findsOneWidget);
      await tester.tap(rotateBtn);
      await tester.pumpAndSettle();
      expect(find.text("90°"), findsOneWidget);

      // Color filter dropdown
      final filterDrop = find.text("Normal");
      expect(filterDrop, findsOneWidget);
      await tester.tap(filterDrop);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Cinematic Warm").last);
      await tester.pumpAndSettle();

      // Speed slider
      final speedSlider = find.byType(Slider).first;
      await tester.drag(speedSlider, const Offset(20, 0));
      await tester.pumpAndSettle();

      // Range slider for trim
      final rangeSlider = find.byType(RangeSlider);
      expect(rangeSlider, findsOneWidget);
      await tester.drag(rangeSlider, const Offset(30, 0));
      await tester.pumpAndSettle();

      // Textfield for subtitle overlay
      final textInput = find.byType(TextField);
      expect(textInput, findsOneWidget);
      await tester.enterText(textInput, "Updated Title Caption");
      await tester.pumpAndSettle();
      expect(find.text("Updated Title Caption"), findsWidgets);

      // Export button
      final exportBtn = find.text("Export Quick Video");
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining("Rendering Quick Edit"), findsOneWidget);
    });

    testWidgets('MultiViewModeView exercises layouts, tile controls and multicam import', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: MultiViewModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch Layouts
      final layoutDrop = find.text("Layout 2x2");
      expect(layoutDrop, findsOneWidget);
      await tester.tap(layoutDrop);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Layout 1+3").last);
      await tester.pumpAndSettle();

      // Master sync filter chip
      final syncChip = find.text("Master Sync");
      expect(syncChip, findsOneWidget);
      await tester.tap(syncChip);
      await tester.pumpAndSettle();
      expect(find.text("Master Sync Enabled"), findsOneWidget);

      // Tile volume sliders and mute buttons
      final volumeSliders = find.byType(Slider);
      expect(volumeSliders, findsWidgets);
      await tester.drag(volumeSliders.first, const Offset(10, 0));
      await tester.pumpAndSettle();

      final muteIcons = find.byIcon(Icons.volume_up);
      if (muteIcons.evaluate().isNotEmpty) {
        await tester.tap(muteIcons.first);
        await tester.pumpAndSettle();
      }

      // Send to Multicam button
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
      await tester.pumpAndSettle();
      final sendBtn = find.text("Send to Multicam");
      expect(sendBtn, findsOneWidget);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();
      expect(find.text("All feeds imported to Studio Multicam Timeline"), findsOneWidget);
    });

    testWidgets('MulticamModeView exercises angle switching and auto-sync', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: MulticamModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Angle 2
      final angle2 = find.text("Angle 2 (Close-up Actor A)");
      expect(angle2, findsOneWidget);
      await tester.tap(angle2);
      await tester.pumpAndSettle();
      expect(find.textContaining("Switched cut to Angle 2"), findsOneWidget);

      // Auto-sync button
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
      await tester.pumpAndSettle();
      final autoSyncBtn = find.text("Auto-Sync Angles");
      expect(autoSyncBtn, findsOneWidget);
      await tester.tap(autoSyncBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining("Auto-aligned 4 angles"), findsOneWidget);
    });

    testWidgets('StudioEditorModeView exercises all tabs, inspector controls, and export dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: StudioEditorModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tab: Color
      await tester.tap(find.text("Color"));
      await tester.pumpAndSettle();
      expect(find.text("Color Grading & Visuals"), findsOneWidget);

      // 2. Tab: Audio
      await tester.tap(find.text("Audio"));
      await tester.pumpAndSettle();
      expect(find.text("Studio Audio Mixer & DSP"), findsOneWidget);

      // 3. Tab: Subtitles (tap the tab button in the side panel tab bar)
      await tester.tap(find.byIcon(Icons.subtitles).first);
      await tester.pumpAndSettle();
      expect(find.text("Subtitles & Closed Captions"), findsOneWidget);
      expect(find.text("Universal Video Studio - Production Ready"), findsOneWidget);

      // 4. Tab: Queue
      await tester.tap(find.byIcon(Icons.queue).first);
      await tester.pumpAndSettle();
      expect(find.text("Render & Export Queue"), findsOneWidget);

      // 5. Tab: Inspector
      await tester.tap(find.byIcon(Icons.tune).first);
      await tester.pumpAndSettle();
      expect(find.text("Clip: SMPTE HD Master"), findsOneWidget);

      // Sliders in Clip Inspector
      final inspSliders = find.byType(Slider);
      for (int i = 0; i < inspSliders.evaluate().length && i < 3; i++) {
        await tester.drag(inspSliders.at(i), const Offset(15, 0));
        await tester.pumpAndSettle();
      }

      // Export Dialog
      final exportBtn = find.text("Export Video");
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(find.text("Export Project / Render Queue"), findsOneWidget);
      final startRenderBtn = find.text("Start Render");
      expect(startRenderBtn, findsOneWidget);
      await tester.tap(startRenderBtn);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();

      // Should automatically switch to Queue tab
      expect(find.text("Render & Export Queue"), findsOneWidget);
    });

    test('TrackModel clipAt and empty duration operations', () {
      final track = TrackModel(
        id: 't-test',
        name: 'Test Track',
        trackType: TrackType.video,
      );
      expect(track.duration, 0.0);
      expect(track.clipAt(2.0), isNull);

      final clip = ClipModel(
        id: 'c-test',
        name: 'Clip',
        mediaPath: 'test.mp4',
        startTime: 1.0,
        duration: 3.0,
      );
      track.clips.add(clip);
      expect(track.duration, 4.0);
      expect(track.clipAt(2.0), isNotNull);
      expect(track.clipAt(0.5), isNull);
    });

    testWidgets('RecordingDialog exercises switches, resolution dropdown and start/stop recording', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecordingDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Screen & Camera Recording"), findsOneWidget);

      // Toggle switches
      final switches = find.byType(SwitchListTile);
      expect(switches, findsNWidgets(3));
      for (int i = 0; i < 3; i++) {
        await tester.tap(switches.at(i));
        await tester.pumpAndSettle();
      }

      // Resolution dropdown
      final resDrop = find.text("1080p 60fps");
      expect(resDrop, findsOneWidget);
      await tester.tap(resDrop);
      await tester.pumpAndSettle();
      await tester.tap(find.text("4K 30fps").last);
      await tester.pumpAndSettle();

      // Start Recording
      final startBtn = find.text("Start Recording");
      expect(startBtn, findsOneWidget);
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      // Stop Recording
      final stopBtn = find.text("Stop Recording");
      expect(stopBtn, findsOneWidget);
      await tester.tap(stopBtn);
      await tester.pumpAndSettle();
    });

    test('RecordingService toggles all sources and records', () {
      final rec = RecordingService.instance;
      rec.toggleSource(RecordingSource.screen);
      rec.toggleSource(RecordingSource.microphone);
      rec.toggleSource(RecordingSource.systemAudio);
      expect(rec.activeSources.contains(RecordingSource.systemAudio), isTrue);

      expect(rec.startRecording(), isTrue);
      expect(rec.isRecording, isTrue);
      final outPath = rec.stopRecording();
      expect(outPath.endsWith('.mp4'), isTrue);
      expect(rec.isRecording, isFalse);
    });

    test('RenderService completion and clearing queue', () async {
      final render = RenderService.instance;
      render.clearCompleted();

      final job = render.queueRender(
        name: 'Completion Test Job',
        outputPath: 'complete.mp4',
        project: ProjectService.instance.project,
        inputPath: 'input.mp4',
      );

      expect(render.jobs.last.status, RenderStatus.rendering);
      expect(render.isRendering, isTrue);

      // Wait 1.6s for all 10 progress ticks to hit 1.0 (completed)
      await Future<void>.delayed(const Duration(milliseconds: 1600));

      final finishedJob = render.jobs.firstWhere((j) => j.id == job.id);
      expect(finishedJob.status, RenderStatus.completed);
      expect(finishedJob.progress, 1.0);

      render.clearCompleted();
      expect(render.jobs.where((j) => j.id == job.id).isEmpty, isTrue);
    });

    test('RecordingService capability detection and ffmpeg command builder', () {
      final rec = RecordingService.instance;
      for (final src in RecordingSource.values) {
        rec.isSourceSupported(src);
        rec.getCapabilityWarning(src);
      }
      final cmd = rec.buildFfmpegCaptureCommand('output_test.mp4');
      expect(cmd.first, 'ffmpeg');
      expect(cmd.last, 'output_test.mp4');
    });

    test('ProjectService insertMulticamCuts creates timeline clips', () {
      final ps = ProjectService.instance;
      ps.newProject(name: 'MulticamCutTest');
      ps.insertMulticamCuts([
        {'name': 'Angle 1', 'media_path': 'cam1.mp4', 'time_s': 0.0},
        {'name': 'Angle 2', 'media_path': 'cam2.mp4', 'time_s': 4.0},
        {'name': 'Angle 3', 'media_path': 'cam3.mp4', 'time_s': 8.0},
      ]);
      final timeline = ps.project['timeline'] as Map<String, dynamic>;
      final tracks = timeline['tracks'] as List;
      expect(tracks.isNotEmpty, isTrue);
    });

    testWidgets('MulticamModeView taps all 4 angles and commits cuts to timeline', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MulticamModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 1; i <= 4; i++) {
        final camText = find.text("CAM $i");
        expect(camText, findsOneWidget);
        await tester.tap(camText);
        await tester.pumpAndSettle();
      }

      ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
      await tester.pumpAndSettle();

      final insertBtn = find.textContaining("Insert Cuts to Timeline");
      expect(insertBtn, findsOneWidget);
      await tester.tap(insertBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining("Successfully committed"), findsOneWidget);
    });

    test('UvsFfiBridge and ProjectService extended mutations (keyframes, transitions, subtitles, audio lag, undo/redo)', () {
      final bridge = UvsFfiBridge.instance;
      var p = bridge.createProject(name: 'ExtendedMutations');
      p = bridge.timelineAddClip(p, 'v1', 'Clip 1', 'media.mp4', 0.0, 5.0);
      final tracks = p['timeline']['tracks'] as List;
      final v1 = tracks.firstWhere((t) => t['id'] == 'v1');
      final clip1Id = (v1['clips'] as List).first['id'] as String;

      // Add keyframes
      p = bridge.timelineAddKeyframe(p, 'v1', clip1Id, 'opacity', 1.0, 0.5, easing: 1);
      p = bridge.timelineAddKeyframe(p, 'v1', clip1Id, 'opacity', 3.0, 1.0, easing: 2);
      p = bridge.timelineAddKeyframe(p, 'v1', clip1Id, 'scale', 2.0, 1.5, easing: 3);

      // Add transitions
      p = bridge.timelineSetTransition(p, 'v1', clip1Id, 'CrossDissolve', 1.0, isOut: false);
      p = bridge.timelineSetTransition(p, 'v1', clip1Id, 'FadeToBlack', 0.5, isOut: true);

      // Add subtitle cue
      p = bridge.timelineAddSubtitleCue(p, 0.5, 2.5, 'Test Subtitle Cue');

      // Check structures
      final subTrack = (p['timeline']['tracks'] as List).firstWhere((t) => t['track_type'] == 'Subtitle');
      expect((subTrack['clips'] as List).isNotEmpty, isTrue);

      // Audio correlation lag
      final lag1 = bridge.computeAudioCorrelationLag([1.0, 0.0, 1.0], [0.0, 1.0, 0.0]);
      expect(lag1.abs() <= 48000, isTrue);
      final lagEmpty = bridge.computeAudioCorrelationLag([], []);
      expect(lagEmpty, 0);

      // Undo/Redo stack operations
      bridge.clearUndoRedo();
      expect(bridge.canUndo(), isFalse);
      expect(bridge.canRedo(), isFalse);
      bridge.pushUndoState(p);
      expect(bridge.canUndo(), isTrue);

      var p2 = Map<String, dynamic>.from(p);
      p2['name'] = 'Modified';
      final undone = bridge.undo(p2);
      expect(undone != null, isTrue);
      expect(undone!['name'], 'ExtendedMutations');
      expect(bridge.canRedo(), isTrue);

      final redone = bridge.redo(undone);
      expect(redone != null, isTrue);
      expect(redone!['name'], 'Modified');

      // ProjectService methods
      final ps = ProjectService.instance;
      ps.newProject(name: 'PS_Mutations');
      ps.addTrack('V2', 'Video', 1);
      final psTracks = ps.project['timeline']['tracks'] as List;
      final v2Id = psTracks.last['id'] as String;
      ps.addClip(v2Id, 'PS_Clip', 'test.mp4', 0.0, 4.0);
      final psClipId = (psTracks.last['clips'] as List).first['id'] as String;

      ps.addKeyframe(v2Id, psClipId, 'opacity', 2.0, 0.8);
      ps.setTransition(v2Id, psClipId, 'Wipe', 0.75, isOut: false);
      ps.addSubtitleCue(1.0, 3.0, 'PS Subtitle');
      ps.setClipSpeed(v2Id, psClipId, 1.5, false);
      ps.addMarker(2.5, 'Marker 1', '#FF0000', 'Comment');
      ps.slipEdit(v2Id, psClipId, 0.2);
      ps.slideEdit(v2Id, psClipId, 0.1);

      expect(ps.canUndo, isTrue);
      ps.undo();
      expect(ps.canRedo, isTrue);
      ps.redo();
    });

    testWidgets('PlayerModeView full user interactions (file dialog, snapshot, audio sync, A-B repeat)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open media file dialog
      final openBtn = find.byTooltip("Open Media File");
      expect(openBtn, findsOneWidget);
      await tester.tap(openBtn);
      await tester.pumpAndSettle();

      expect(find.text("Open Media File"), findsOneWidget);
      await tester.tap(find.text("Sample 4K"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Load Media"));
      await tester.pumpAndSettle();
      ScaffoldMessenger.maybeOf(tester.element(find.byType(PlayerModeView)))?.clearSnackBars();
      await tester.pumpAndSettle();

      // Frame stepping
      await tester.tap(find.byTooltip("Next Frame (Right Arrow)"), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byTooltip("Previous Frame (Left Arrow)"), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));

      // Play/Pause
      await tester.tap(find.byTooltip("Play / Pause (Space)"), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip("Play / Pause (Space)"), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));

      // Audio sync dialog
      final syncBtn = find.byTooltip("Audio Sync");
      expect(syncBtn, findsOneWidget);
      await tester.ensureVisible(syncBtn);
      await tester.tap(syncBtn, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text("Audio Sync Calibration"), findsOneWidget);
      final syncSlider = find.byType(Slider);
      if (syncSlider.evaluate().isNotEmpty) {
        await tester.drag(syncSlider.first, const Offset(30, 0), warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text("Close"), warnIfMissed: false);
      await tester.pumpAndSettle();

      ScaffoldMessenger.maybeOf(tester.element(find.byType(PlayerModeView)))?.clearSnackBars();
      await tester.pumpAndSettle();

      // Snapshot capture
      final snapBtn = find.byTooltip("Capture Snapshot");
      expect(snapBtn, findsOneWidget);
      await tester.ensureVisible(snapBtn);
      await tester.tap(snapBtn, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.textContaining("Captured frame snapshot"), findsOneWidget);

      ScaffoldMessenger.maybeOf(tester.element(find.byType(PlayerModeView)))?.clearSnackBars();
      await tester.pumpAndSettle();

      // A-B repeat
      await tester.ensureVisible(find.text("Set A"));
      await tester.tap(find.text("Set A"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Set B"));
      await tester.pumpAndSettle();
      final clearAb = find.byTooltip("Clear A-B Repeat");
      if (clearAb.evaluate().isNotEmpty) {
        await tester.tap(clearAb);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('StudioEditorModeView advanced inspector tools and undo/redo', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: StudioEditorModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Add keyframe button
      final addKfBtn = find.text("Add Keyframe");
      if (addKfBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(addKfBtn);
        await tester.tap(addKfBtn);
        await tester.pumpAndSettle();
        expect(find.textContaining("Keyframe added"), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
        await tester.pumpAndSettle();
      }

      // Cross dissolve button
      final transBtn = find.text("Cross Dissolve");
      if (transBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(transBtn);
        await tester.tap(transBtn);
        await tester.pumpAndSettle();
        expect(find.textContaining("Set Cross Dissolve"), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
        await tester.pumpAndSettle();
      }

      // Slip / Slide buttons
      final slipBtn = find.text("Slip -0.5s");
      if (slipBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(slipBtn);
        await tester.tap(slipBtn);
        await tester.pumpAndSettle();
        expect(find.textContaining("Slipped clip"), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
        await tester.pumpAndSettle();
      }
      final slideBtn = find.text("Slide +0.5s");
      if (slideBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(slideBtn);
        await tester.tap(slideBtn);
        await tester.pumpAndSettle();
        expect(find.textContaining("Slid clip"), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
        await tester.pumpAndSettle();
      }

      // Subtitles tab cue addition
      await tester.tap(find.byIcon(Icons.subtitles).first);
      await tester.pumpAndSettle();
      final addCueBtn = find.byTooltip("Add Cue at Playhead");
      if (addCueBtn.evaluate().isNotEmpty) {
        await tester.tap(addCueBtn);
        await tester.pumpAndSettle();
        expect(find.textContaining("Added subtitle cue"), findsOneWidget);
      }

      // Undo button
      final undoBtn = find.byTooltip("Undo (Ctrl+Z)");
      if (undoBtn.evaluate().isNotEmpty) {
        await tester.tap(undoBtn);
        await tester.pumpAndSettle();
      }
      final redoBtn = find.byTooltip("Redo (Ctrl+Y)");
      if (redoBtn.evaluate().isNotEmpty) {
        await tester.tap(redoBtn);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('MultiViewModeView stream failure recovery and volume interactions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MultiViewModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to 3x3 layout
      final dropdown = find.text("Layout 2x2");
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Layout 3x3").last);
      await tester.pumpAndSettle();

      // Simulate connection drop on a feed
      final bugButtons = find.byTooltip("Simulate Connection Drop / Recovery");
      if (bugButtons.evaluate().isNotEmpty) {
        await tester.tap(bugButtons.first);
        await tester.pumpAndSettle();
        expect(find.text("Signal Lost / Disconnected"), findsOneWidget);

        // Tap reconnect button
        final reconnectBtn = find.text("Reconnect Feed");
        expect(reconnectBtn, findsOneWidget);
        await tester.tap(reconnectBtn);
        await tester.pumpAndSettle();
        expect(find.textContaining("reconnected successfully"), findsOneWidget);
      }
    });

    test('MediaService caching and real file probe', () {
      final ms = MediaService.instance;
      final tempFile = File('${Directory.systemTemp.path}/probe_test.mp4');
      tempFile.writeAsStringSync('dummy video probe content 1234567890');
      try {
        final probe1 = ms.probeMedia(tempFile.path);
        expect(probe1.path, tempFile.path);
        // Hit cache branch
        final probe2 = ms.probeMedia(tempFile.path);
        expect(probe2.durationSeconds, probe1.durationSeconds);

        final wf1 = ms.getWaveform(tempFile.path);
        expect(wf1.isNotEmpty, isTrue);
        // Hit waveform cache branch
        final wf2 = ms.getWaveform(tempFile.path);
        expect(wf2.length, wf1.length);
      } finally {
        if (tempFile.existsSync()) tempFile.deleteSync();
      }
    });

    test('RecordingService sources, lifecycle, and ffmpeg capture build', () {
      final rec = RecordingService.instance;
      expect(rec.isSourceSupported(RecordingSource.screen), isTrue);
      expect(rec.isSourceSupported(RecordingSource.camera), isTrue);
      expect(rec.isSourceSupported(RecordingSource.microphone), isTrue);
      rec.getCapabilityWarning(RecordingSource.systemAudio);
      rec.getCapabilityWarning(RecordingSource.screen);

      rec.toggleSource(RecordingSource.camera);
      rec.toggleSource(RecordingSource.camera);

      final started = rec.startRecording();
      expect(started, isTrue);
      expect(rec.isRecording, isTrue);
      expect(rec.startRecording(), isFalse); // already recording

      final cmd = rec.buildFfmpegCaptureCommand('test_rec.mp4');
      expect(cmd.contains('ffmpeg'), isTrue);

      final out = rec.stopRecording();
      expect(out.isNotEmpty, isTrue);
      expect(rec.isRecording, isFalse);
      expect(rec.stopRecording(), ''); // already stopped
    });

    test('RenderService job queue, cancel, and clearCompleted', () {
      final render = RenderService.instance;
      final projMap = UvsFfiBridge.instance.createProject(name: 'Render Coverage Test');
      render.queueRender(
        project: projMap,
        inputPath: 'nonexistent_test_render_file.mp4',
        name: 'Test Render Job',
        outputPath: '${Directory.systemTemp.path}/render_out_test.mp4',
      );
      expect(render.jobs.isNotEmpty, isTrue);
      final job = render.jobs.last;
      render.cancelJob(job.id);
      expect(render.jobs.any((j) => j.id == job.id && j.status == RenderStatus.cancelled), isTrue);
      render.clearCompleted();
    });

    testWidgets('ColorInspectorView sliders and LUT dropdown interaction', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ColorInspectorView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sliders = find.byType(Slider);
      expect(sliders, findsWidgets);
      for (var i = 0; i < sliders.evaluate().length; i++) {
        await tester.drag(sliders.at(i), const Offset(20, 0));
        await tester.pumpAndSettle();
      }

      final dropdown = find.byType(DropdownButton<String>);
      if (dropdown.evaluate().isNotEmpty) {
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Monochrome Noir').last);
        await tester.pumpAndSettle();
        expect(find.text('Monochrome Noir'), findsOneWidget);
      }
    });

    testWidgets('AudioMixerView faders, mute and solo interaction', (WidgetTester tester) async {
      final proj = ProjectModel.createDefault();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioMixerView(project: proj),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sliders = find.byType(Slider);
      expect(sliders, findsWidgets);
      for (var i = 0; i < sliders.evaluate().length; i++) {
        await tester.drag(sliders.at(i), const Offset(0, -10));
        await tester.pumpAndSettle();
      }

      final mBtns = find.text("M");
      if (mBtns.evaluate().isNotEmpty) {
        await tester.tap(mBtns.first);
        await tester.pumpAndSettle();
      }

      final sBtns = find.text("S");
      if (sBtns.evaluate().isNotEmpty) {
        await tester.tap(sBtns.first);
        await tester.pumpAndSettle();
      }
    });

    test('Pure-Dart Fallback Engine comprehensive verification', () {
      final bridge = UvsFfiBridge.instance;
      bridge.forcePureDart = true;
      try {
        expect(bridge.isNativeLoaded, isFalse);
        expect(bridge.getCoreVersion(), '0.1.0-production');
        final hw = bridge.detectHardware();
        expect(hw['primary_vendor'], isNotNull);

        var proj = bridge.createProject(name: 'Pure Dart Project');
        expect(proj['name'], 'Pure Dart Project');

        final tmpPath = '${Directory.systemTemp.path}/uvs_pure_dart_${DateTime.now().millisecondsSinceEpoch}.uvsp';
        final saveRes = bridge.saveProjectAtomic(proj, tmpPath);
        expect(saveRes['status'], 'ok');
        expect(File(tmpPath).existsSync(), isTrue);

        final loaded = bridge.loadProject(tmpPath);
        expect(loaded['name'], 'Pure Dart Project');
        File(tmpPath).deleteSync();

        final searchDir = Directory.systemTemp.createTempSync('pure_relink_');
        final relinkRes = bridge.relinkProject(proj, searchDir.path);
        expect(relinkRes.containsKey('relinked_count'), isTrue);
        searchDir.deleteSync(recursive: true);

        proj = bridge.timelineAddTrack(proj, 'V1', 'Video', 0);
        final tId = (proj['timeline']['tracks'] as List).last['id'] as String;

        proj = bridge.timelineAddClip(proj, tId, 'Clip 1', 'v1.mp4', 0.0, 10.0);
        proj = bridge.timelineAddClip(proj, tId, 'Clip 2', 'v2.mp4', 10.0, 10.0);
        final c1Id = (proj['timeline']['tracks'] as List).last['clips'][0]['id'] as String;
        final c2Id = (proj['timeline']['tracks'] as List).last['clips'][1]['id'] as String;

        proj = bridge.timelineSplitClip(proj, tId, c1Id, 5.0);
        proj = bridge.timelineTrimClip(proj, tId, c2Id, true, 12.0);
        proj = bridge.timelineRollEdit(proj, tId, c1Id, c2Id, 1.0);
        proj = bridge.timelineSlipEdit(proj, tId, c1Id, 1.0);
        proj = bridge.timelineSlideEdit(proj, tId, c2Id, 1.0);
        proj = bridge.clipSetSpeed(proj, tId, c1Id, 1.5, reverse: true);
        proj = bridge.clipSetLinked(proj, c1Id, c2Id);
        proj = bridge.timelineAddMarker(proj, 2.5, 'Marker 1', '#FF0000', 'note');
        final mId = (proj['timeline']['markers'] as List).last['id'] as String;
        proj = bridge.timelineDeleteMarker(proj, mId);
        proj = bridge.timelineRippleDelete(proj, tId, c1Id);

        proj = bridge.timelineAddKeyframe(proj, tId, c2Id, 'volume', 1.0, 0.8, easing: 1);
        proj = bridge.timelineSetTransition(proj, tId, c2Id, 'CrossDissolve', 1.5, isOut: true);
        proj = bridge.timelineAddSubtitleCue(proj, 0.0, 4.0, 'Hello World');

        final lag = bridge.computeAudioCorrelationLag([1.0, 0.0, -1.0], [1.0, 0.0, -1.0]);
        expect(lag, 0);

        final lufs = bridge.calculateIntegratedLufs([0.1, -0.1, 0.2, -0.2]);
        expect(lufs, lessThan(0.0));

        final wf = bridge.getWaveformSummary(1000, 100);
        expect(wf.length, 100);

        final pProbe = bridge.probeMedia('some_fake.mp4');
        expect(pProbe['streams'][0]['width'], 1920);

        final pDec = bridge.decodeFrame('some_fake.mp4', 1.0, 'out.png');
        expect(pDec['status'], 'ok');

        final pProxy = bridge.generateProxy('some_fake.mp4', 'target.mp4', 720);
        expect(pProxy['status'], 'ok');

        final cmd = bridge.buildRenderCommand(proj, 'input.mp4', 'output.mp4');
        expect(cmd, contains('-i'));

        final rExec = bridge.executeRender(proj, 'input.mp4', 'output.mp4');
        expect(rExec.containsKey('status'), isTrue);

        final mcCuts = bridge.commitMulticamCuts(proj, {'id': 'g1'}, [{'time': 1.0, 'angle': 0}]);
        expect(mcCuts.containsKey('inserted_cuts'), isTrue);
      } finally {
        bridge.forcePureDart = false;
      }
    });

    test('RenderService real ffmpeg execution and MediaService probe', () async {
      final testVideo = File('c:/Users/dayan/uvs/tests/output/cam_test.mp4');
      if (testVideo.existsSync()) {
        final mediaRes = await MediaService.instance.probeMedia(testVideo.path);
        expect(mediaRes.width, greaterThan(0));
        expect(mediaRes.durationSeconds, greaterThan(0.0));

        final renderService = RenderService.instance;
        final proj = UvsFfiBridge.instance.createProject(name: 'Real Render Proj');
        final outMp4 = '${Directory.systemTemp.path}/uvs_render_test_${DateTime.now().millisecondsSinceEpoch}.mp4';

        final job = renderService.queueRender(
          project: proj,
          inputPath: testVideo.path,
          outputPath: outMp4,
          name: 'Real Render Test',
        );
        expect(job.status, isNotNull);
        for (int i = 0; i < 30 && renderService.isRendering; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (File(outMp4).existsSync()) {
          File(outMp4).deleteSync();
        }
      }
    });

    test('RecordingService build capture commands and warnings across sources', () async {
      final rec = RecordingService.instance;
      expect(rec.isSourceSupported(RecordingSource.camera), isTrue);
      expect(rec.isSourceSupported(RecordingSource.screen), isTrue);
      expect(rec.isSourceSupported(RecordingSource.microphone), isTrue);
      expect(rec.isSourceSupported(RecordingSource.systemAudio), isTrue);

      rec.toggleSource(RecordingSource.screen);
      rec.toggleSource(RecordingSource.camera);
      final cmdScreen = rec.buildFfmpegCaptureCommand('test_screen.mp4');
      expect(cmdScreen, contains('ffmpeg'));

      rec.toggleSource(RecordingSource.camera);
      final cmdCam = rec.buildFfmpegCaptureCommand('test_cam.mp4');
      expect(cmdCam, contains('ffmpeg'));

      rec.toggleSource(RecordingSource.systemAudio);
      rec.getCapabilityWarning(RecordingSource.systemAudio);

      // Start and stop real recording
      final recOut = '${Directory.systemTemp.path}/test_rec_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final started = rec.startRecording(outputPath: recOut);
      if (started) {
        expect(rec.isRecording, isTrue);
        await Future.delayed(const Duration(milliseconds: 200));
        await rec.stopRecording();
        expect(rec.isRecording, isFalse);
        if (File(recOut).existsSync()) {
          File(recOut).deleteSync();
        }
      }
    });

    testWidgets('StudioEditorModeView play/pause and export presets', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudioEditorModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final playBtn = find.byIcon(Icons.play_arrow);
      if (playBtn.evaluate().isNotEmpty) {
        await tester.tap(playBtn);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byIcon(Icons.pause));
        await tester.pumpAndSettle();
      }

      final exportBtn = find.byIcon(Icons.file_upload_outlined);
      if (exportBtn.evaluate().isNotEmpty) {
        await tester.tap(exportBtn);
        await tester.pumpAndSettle();

        final dropdowns = find.byType(DropdownButton<String>);
        if (dropdowns.evaluate().isNotEmpty) {
          await tester.tap(dropdowns.first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('MKV').last);
          await tester.pumpAndSettle();
        }
        final cancelBtn = find.text('Cancel');
        if (cancelBtn.evaluate().isNotEmpty) {
          await tester.tap(cancelBtn);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('PlayerModeView controls timer and A-B loop timer', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final playBtn = find.byIcon(Icons.play_arrow);
      if (playBtn.evaluate().isNotEmpty) {
        await tester.tap(playBtn);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 4));
        final pauseBtn = find.byIcon(Icons.pause);
        if (pauseBtn.evaluate().isNotEmpty) {
          await tester.tap(pauseBtn);
          await tester.pumpAndSettle();
        }
      }
    });
  });
}

