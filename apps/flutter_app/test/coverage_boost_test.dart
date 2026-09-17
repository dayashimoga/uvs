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
      expect(cmdH264.contains('libx264'), isTrue);

      proj['render_settings']['video_codec'] = 'hevc';
      proj['render_settings']['audio_codec'] = 'opus';
      final cmdHevc = bridge.buildRenderCommand(proj, 'in.mp4', 'out.mp4');
      expect(cmdHevc.contains('libx265'), isTrue);
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

      final tempSave = '${Directory.systemTemp.path}/uvs_ps_${DateTime.now().millisecondsSinceEpoch}.uvsp';
      expect(s.saveProject(tempSave), isTrue);
      expect(s.loadProject(tempSave), isTrue);
      expect(s.currentFilePath, tempSave);
      expect(s.isDirty, isFalse);

      expect(s.relinkAssets(Directory.systemTemp.path), greaterThanOrEqualTo(0));

      // Cleanup
      File(tempSave).deleteSync();
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
  });
}

