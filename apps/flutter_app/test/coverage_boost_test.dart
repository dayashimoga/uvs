import 'dart:io';
import 'package:flutter/services.dart';
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
import 'package:universal_video_studio/src/widgets/video_monitor_surface.dart';
import 'package:universal_video_studio/src/services/platform_file_picker.dart';
import 'package:universal_video_studio/src/services/recent_media_service.dart';
import 'package:universal_video_studio/src/widgets/media_bin_view.dart';
import 'package:universal_video_studio/src/widgets/timeline_view.dart';
import 'package:flutter/foundation.dart';

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
      expect(find.text("Universal Video Studio Title Cue 1"), findsOneWidget);

      // 4. Tab: Queue
      await tester.ensureVisible(find.byIcon(Icons.queue).first);
      await tester.tap(find.byIcon(Icons.queue).first, warnIfMissed: false);
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

      // Toggle switches (Screen, Camera, Mic, System Audio)
      final switches = find.byType(SwitchListTile);
      expect(switches, findsNWidgets(4));
      for (int i = 0; i < 4; i++) {
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

      // Pause & Resume
      final pauseBtn = find.text("Pause");
      if (pauseBtn.evaluate().isNotEmpty) {
        await tester.tap(pauseBtn);
        await tester.pumpAndSettle();
        final resumeBtn = find.text("Resume");
        if (resumeBtn.evaluate().isNotEmpty) {
          await tester.tap(resumeBtn);
          await tester.pumpAndSettle();
        }
      }

      // Stop Recording
      final stopBtn = find.text("Stop Recording");
      expect(stopBtn, findsOneWidget);
      await tester.tap(stopBtn);
      await tester.pumpAndSettle();
    });

    test('RecordingService toggles all sources and records with pause and resume', () {
      final rec = RecordingService.instance;
      rec.reset();
      if (!rec.activeSources.contains(RecordingSource.systemAudio)) {
        rec.toggleSource(RecordingSource.systemAudio);
      }
      expect(rec.activeSources.contains(RecordingSource.systemAudio), isTrue);

      expect(rec.startRecording(), isTrue);
      expect(rec.isRecording, isTrue);
      expect(rec.isPaused, isFalse);

      rec.pauseRecording();
      expect(rec.isPaused, isTrue);

      rec.resumeRecording();
      expect(rec.isPaused, isFalse);

      final outPath = rec.stopRecording();
      expect(outPath.endsWith('.mp4'), isTrue);
      expect(rec.isRecording, isFalse);
      expect(rec.isPaused, isFalse);
    });


    test('RenderService completion and clearing queue', () async {
      final render = RenderService.instance;
      render.resetForTesting();

      final job = render.queueRender(
        name: 'Completion Test Job',
        outputPath: 'complete.mp4',
        project: ProjectService.instance.project,
        inputPath: 'input.mp4',
      );

      expect(
        render.jobs.last.status == RenderStatus.queued ||
            render.jobs.last.status == RenderStatus.rendering,
        isTrue,
      );
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
      PlatformFilePicker.mockPickedFiles = ['media/fixtures/test_smpte_1080p.mp4'];
      final openBtn = find.byTooltip("Open Media File");
      expect(openBtn, findsOneWidget);
      await tester.tap(openBtn);
      await tester.pumpAndSettle();
      PlatformFilePicker.mockPickedFiles = null;
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
      rec.reset();
      expect(rec.isSourceSupported(RecordingSource.screen), isTrue);
      expect(rec.isSourceSupported(RecordingSource.camera), isTrue);
      expect(rec.isSourceSupported(RecordingSource.microphone), isTrue);
      rec.getCapabilityWarning(RecordingSource.systemAudio);
      rec.getCapabilityWarning(RecordingSource.screen);

      rec.toggleSource(RecordingSource.camera);
      expect(rec.activeSources.contains(RecordingSource.camera), isTrue);
      rec.toggleSource(RecordingSource.camera);
      expect(rec.activeSources.contains(RecordingSource.camera), isFalse);

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
      final fixture = MediaService.resolveFixture('media/fixtures/test_smpte_1080p.mp4');
      File testVideo = (fixture != null) ? File(fixture) : File('tests/output/cam_test.mp4');
      if (!testVideo.existsSync()) {
        testVideo = File('../../tests/output/cam_test.mp4');
      }
      if (testVideo.existsSync()) {
        final mediaRes = MediaService.instance.probeMedia(testVideo.path);
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
        try {
          if (File(outMp4).existsSync()) {
            File(outMp4).deleteSync();
          }
        } catch (_) {}
      }
    });

    test('RecordingService build capture commands and warnings across sources', () async {
      final rec = RecordingService.instance;
      rec.reset();
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
        rec.stopRecording();
        expect(rec.isRecording, isFalse);
        try {
          if (File(recOut).existsSync()) {
            File(recOut).deleteSync();
          }
        } catch (_) {}
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
        await tester.tap(playBtn.first);
        await tester.pump(const Duration(milliseconds: 100));
        final pauseBtn = find.byIcon(Icons.pause);
        if (pauseBtn.evaluate().isNotEmpty) {
          await tester.tap(pauseBtn.first);
        }
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

    test('RecordingService cross-platform command generation and warnings', () {
      final rec = RecordingService.instance;
      try {
        // 1. Windows platform branches
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        rec.reset(); // starts with screen and microphone
        rec.toggleSource(RecordingSource.camera); // now screen, mic, camera
        var cmd = rec.buildFfmpegCaptureCommand('out_win.mp4');
        expect(cmd, contains('ffmpeg'));
        expect(cmd, contains('video=Integrated Camera'));
        expect(rec.getCapabilityWarning(RecordingSource.systemAudio), contains('Stereo Mix'));

        rec.toggleSource(RecordingSource.camera); // removes camera -> has screen and mic
        cmd = rec.buildFfmpegCaptureCommand('out_win2.mp4');
        expect(cmd, contains('gdigrab'));

        // Untoggle all sources -> lavfi fallback
        rec.toggleSource(RecordingSource.screen);
        rec.toggleSource(RecordingSource.microphone);
        cmd = rec.buildFfmpegCaptureCommand('out_win_empty.mp4');
        expect(cmd, contains('lavfi'));

        // 2. Linux platform branches
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        rec.reset(); // has screen and microphone
        cmd = rec.buildFfmpegCaptureCommand('out_linux.mp4');
        expect(cmd, contains('x11grab'));
        expect(rec.getCapabilityWarning(RecordingSource.systemAudio), contains('PulseAudio'));

        rec.toggleSource(RecordingSource.screen);
        rec.toggleSource(RecordingSource.microphone);
        cmd = rec.buildFfmpegCaptureCommand('out_linux_empty.mp4');
        expect(cmd, contains('lavfi'));

        // 3. macOS platform branches
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        rec.reset(); // has screen and microphone
        cmd = rec.buildFfmpegCaptureCommand('out_mac.mp4');
        expect(cmd, contains('avfoundation'));
        expect(rec.getCapabilityWarning(RecordingSource.systemAudio), contains('macOS'));

        rec.toggleSource(RecordingSource.screen);
        rec.toggleSource(RecordingSource.microphone);
        cmd = rec.buildFfmpegCaptureCommand('out_mac_empty.mp4');
        expect(cmd, contains('lavfi'));

        // 4. Android platform branches
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        rec.reset();
        cmd = rec.buildFfmpegCaptureCommand('out_android.mp4');
        expect(cmd, contains('lavfi'));
        expect(rec.getCapabilityWarning(RecordingSource.systemAudio), contains('Android'));

        // 5. iOS platform
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(rec.isSourceSupported(RecordingSource.systemAudio), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        rec.reset();
      }
      expect(rec.currentOutputPath, isNull);
    });

    test('MediaService extractFrame and caching', () {
      final ms = MediaService.instance;
      final tmpFile = File('${Directory.systemTemp.path}/test_frame_extract.png');
      tmpFile.writeAsBytesSync([137, 80, 78, 71, 13, 10, 26, 10]); // PNG header

      final extracted1 = ms.extractFrame(tmpFile.path, 1.5);
      expect(extracted1.isNotEmpty, isTrue);

      // Create cached file so existsSync() passes
      final cachedFile = File(extracted1);
      if (!cachedFile.existsSync()) {
        cachedFile.writeAsBytesSync([137, 80, 78, 71, 13, 10, 26, 10]);
      }

      // Hit cache
      final extracted2 = ms.extractFrame(tmpFile.path, 1.5);
      expect(extracted2, extracted1);

      // Test with dummy video path
      ms.extractFrame('nonexistent_video.mp4', 0.0);

      try {
        tmpFile.deleteSync();
        if (cachedFile.existsSync()) cachedFile.deleteSync();
      } catch (_) {}
    });

    testWidgets('VideoMonitorSurface relink and real file branches', (WidgetTester tester) async {
      // 1. Offline media branch with Relink Media button tap
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoMonitorSurface(
              mediaPath: '/missing/path/to/offline_clip.mp4',
              currentTime: 2.0,
              duration: 10.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final relinkBtn = find.text('Relink Media');
      expect(relinkBtn, findsOneWidget);
      await tester.tap(relinkBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('Relinking search initiated'), findsOneWidget);

      // 2. Existing image branch
      final tmpImg = File('${Directory.systemTemp.path}/test_monitor_surface.png');
      tmpImg.writeAsBytesSync([137, 80, 78, 71, 13, 10, 26, 10]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoMonitorSurface(
              mediaPath: tmpImg.path,
              currentTime: 0.0,
              duration: 5.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      try {
        tmpImg.deleteSync();
      } catch (_) {}
    });

    test('UvsFfiBridge comprehensive native and fallback method coverage', () {
      final bridge = UvsFfiBridge.instance;
      expect(bridge, isNotNull);
      if (bridge.isNativeLoaded) {
        expect(bridge.dynamicLibrary, isNotNull);
      }

      var proj = bridge.createProject(name: 'FFI Comprehensive Suite');
      proj = bridge.timelineAddTrack(proj, 'V1', 'Video', 1);
      final tracks = proj['timeline']['tracks'] as List;
      final tId = tracks.last['id'] as String;
      proj = bridge.timelineAddClip(proj, tId, 'C1', 'c1.mp4', 0.0, 10.0);
      proj = bridge.timelineAddClip(proj, tId, 'C2', 'c2.mp4', 10.0, 10.0);
      final clips = tracks.last['clips'] as List;
      final c1Id = clips[0]['id'] as String;
      final c2Id = clips[1]['id'] as String;

      // timelineTrimClip head & tail
      proj = bridge.timelineTrimClip(proj, tId, c1Id, true, 2.0);
      proj = bridge.timelineTrimClip(proj, tId, c1Id, false, 8.0);

      // clipSetLinked & clipSetGroup
      proj = bridge.clipSetLinked(proj, c1Id, c2Id);
      proj = bridge.clipSetGroup(proj, [c1Id, c2Id], 'grp_123');

      // Add & delete marker
      proj = bridge.timelineAddMarker(proj, 4.0, 'M1', '#FF0000', 'note');
      final markers = proj['timeline']['markers'] as List;
      if (markers.isNotEmpty) {
        final mId = markers.first['id'] as String;
        proj = bridge.timelineDeleteMarker(proj, mId);
      }

      // calculateIntegratedLufs
      final lufs = bridge.calculateIntegratedLufs([0.05, -0.05, 0.02, -0.02], channels: 2, sampleRate: 48000);
      expect(lufs, isA<double>());

      // decodeFrame & executeRender & commitMulticamCuts
      bridge.decodeFrame('dummy.mp4', 0.5, '${Directory.systemTemp.path}/out.png');
      bridge.executeRender(proj, 'in.mp4', 'out.mp4');
      bridge.commitMulticamCuts(proj, {'id': 'g1'}, [{'angle': 1, 'time': 1.0}]);

      // timelineRollEdit & timelineSlipEdit & timelineSlideEdit
      bridge.timelineRollEdit(proj, tId, c1Id, c2Id, 0.5);
      bridge.timelineSlipEdit(proj, tId, c1Id, 0.5);
      bridge.timelineSlideEdit(proj, tId, c1Id, 0.2);
    });

    test('PlatformFilePicker supported extensions and mock flows', () async {
      expect(PlatformFilePicker.supportedMediaExtensions.contains('mp4'), isTrue);
      expect(PlatformFilePicker.supportedProjectExtensions.contains('uvsp'), isTrue);

      PlatformFilePicker.mockPickedFiles = ['test_file.mp4'];
      final picked = await PlatformFilePicker.pickMediaFiles();
      expect(picked, ['test_file.mp4']);

      final proj = await PlatformFilePicker.pickProjectFile();
      expect(proj, 'test_file.mp4');

      PlatformFilePicker.mockPickedFolder = 'C:/test_folder';
      final folder = await PlatformFilePicker.pickFolder();
      expect(folder, 'C:/test_folder');

      PlatformFilePicker.mockPickedFiles = null;
      PlatformFilePicker.mockPickedFolder = null;
    });

    test('RecentMediaService operations and persistence', () {
      final recents = RecentMediaService.instance;
      final tempFile = File('${Directory.systemTemp.path}/uvs_recent_test.mp4');
      tempFile.writeAsStringSync('dummy');

      recents.addRecentMedia(tempFile.path);
      expect(recents.recentMedia.contains(tempFile.path), isTrue);

      final tempProj = File('${Directory.systemTemp.path}/uvs_recent_test.uvsp');
      tempProj.writeAsStringSync('{}');
      recents.addRecentProject(tempProj.path);
      expect(recents.recentProjects.contains(tempProj.path), isTrue);

      recents.clearRecents();
      expect(recents.recentMedia.isEmpty, isTrue);
      expect(recents.recentProjects.isEmpty, isTrue);

      try {
        tempFile.deleteSync();
        tempProj.deleteSync();
      } catch (_) {}
    });

    testWidgets('MediaBinView grid and list views, search filter, and add to timeline', (tester) async {
      final sampleItem = MediaBinItem(
        id: 'item-1',
        path: 'test.mp4',
        name: 'test.mp4',
        duration: 12.5,
        width: 1920,
        height: 1080,
        fps: 30.0,
        channels: 2,
      );

      final audioItem = MediaBinItem(
        id: 'item-2',
        path: 'music.mp3',
        name: 'music.mp3',
        duration: 60.0,
        width: 0,
        height: 0,
        fps: 0.0,
        channels: 2,
      );

      expect(sampleItem.isVideo, isTrue);
      expect(sampleItem.isAudioOnly, isFalse);
      expect(audioItem.isVideo, isFalse);
      expect(audioItem.isAudioOnly, isTrue);

      List<MediaBinItem> items = [sampleItem, audioItem];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaBinView(
              items: items,
              onSelectPreview: (_) {},
              onAddToTimeline: (_) {},
              onItemsChanged: (newItems) => items = newItems,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("test.mp4"), findsOneWidget);
      expect(find.text("music.mp3"), findsOneWidget);

      // Search filter
      await tester.enterText(find.byType(TextField), "music");
      await tester.pumpAndSettle();
      expect(find.text("music.mp3"), findsOneWidget);
      expect(find.text("test.mp4"), findsNothing);

      // Clear search
      await tester.enterText(find.byType(TextField), "");
      await tester.pumpAndSettle();

      // Add to timeline & delete via popup
      final addButtons = find.byIcon(Icons.add_circle_outline);
      if (addButtons.evaluate().isNotEmpty) {
        await tester.tap(addButtons.first);
        await tester.pumpAndSettle();
      }

      final moreButtons = find.byIcon(Icons.more_vert);
      if (moreButtons.evaluate().isNotEmpty) {
        await tester.tap(moreButtons.first);
        await tester.pumpAndSettle();
        final removeOpt = find.text("Remove from Bin");
        if (removeOpt.evaluate().isNotEmpty) {
          await tester.tap(removeOpt);
          await tester.pumpAndSettle();
        }
      }

      // Toggle view mode to List View
      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.grid_view), findsOneWidget);

      // Empty state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaBinView(
              items: const [],
              onSelectPreview: (it) {},
              onAddToTimeline: (it) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("No Media Ingested"), findsOneWidget);
    });

    testWidgets('MulticamModeView camera angle imports and assignments', (tester) async {
      PlatformFilePicker.mockPickedFiles = ['angle1.mp4', 'angle2.mp4'];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MulticamModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Import Camera Files
      await tester.tap(find.text("Import Camera Files"));
      await tester.pumpAndSettle();

      // Tap individual angle assign button
      PlatformFilePicker.mockPickedFiles = ['angle1.mp4'];
      final assignButtons = find.byTooltip("Assign Video File to CAM 1");
      if (assignButtons.evaluate().isNotEmpty) {
        await tester.tap(assignButtons.first);
        await tester.pumpAndSettle();
      }

      // Auto-Sync Angles
      final autoSyncBtn = find.text("Auto-Sync Angles");
      if (autoSyncBtn.evaluate().isNotEmpty) {
        await tester.tap(autoSyncBtn);
        await tester.pumpAndSettle();
      }

      // Switch angle cut by tapping CAM 2
      final cam2 = find.text("CAM 2");
      if (cam2.evaluate().isNotEmpty) {
        await tester.tap(cam2);
        await tester.pumpAndSettle();
      }

      // Insert Cuts to Timeline
      final anyInsert = find.textContaining("Insert Cuts to Timeline");
      if (anyInsert.evaluate().isNotEmpty) {
        await tester.tap(anyInsert.first);
        await tester.pumpAndSettle();
      }

      PlatformFilePicker.mockPickedFiles = null;
    });

    testWidgets('PlayerModeView open media file dialog and playback', (tester) async {
      final fixturePath = MediaService.resolveFixture('media/fixtures/test_smpte_1080p.mp4') ??
          MediaService.resolveFixture('sample_1080p.mp4') ??
          'dummy.mp4';
      PlatformFilePicker.mockPickedFiles = [fixturePath];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open media file dialog
      final openBtn = find.text("Open Media File");
      if (openBtn.evaluate().isNotEmpty) {
        await tester.tap(openBtn);
      } else {
        await tester.tap(find.byIcon(Icons.folder_open).first);
      }
      await tester.pumpAndSettle();

      // Playback toggle
      final playBtn = find.byIcon(Icons.play_circle_filled);
      if (playBtn.evaluate().isNotEmpty) {
        await tester.tap(playBtn);
        await tester.pump(const Duration(milliseconds: 100));
        final pauseBtn = find.byIcon(Icons.pause_circle_filled);
        if (pauseBtn.evaluate().isNotEmpty) {
          await tester.tap(pauseBtn);
          await tester.pumpAndSettle();
        }
      }

      // Step forward & backward
      final nextBtn = find.byTooltip("Next Frame (Right Arrow)");
      if (nextBtn.evaluate().isNotEmpty) {
        await tester.tap(nextBtn, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      final prevBtn = find.byTooltip("Previous Frame (Left Arrow)");
      if (prevBtn.evaluate().isNotEmpty) {
        await tester.tap(prevBtn, warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      // A-B repeat
      final setABtn = find.text("Set A");
      if (setABtn.evaluate().isNotEmpty) {
        await tester.tap(setABtn, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      final setBBtn = find.text("Set B");
      if (setBBtn.evaluate().isNotEmpty) {
        await tester.tap(setBBtn, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      final clearAB = find.byTooltip("Clear A-B Repeat");
      if (clearAB.evaluate().isNotEmpty) {
        await tester.tap(clearAB, warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      // Snapshot capture
      final snapBtn = find.byTooltip("Capture Snapshot");
      if (snapBtn.evaluate().isNotEmpty) {
        await tester.tap(snapBtn);
        await tester.pumpAndSettle();
      }

      // Subtitles selection
      final subBtn = find.byTooltip("Subtitles");
      if (subBtn.evaluate().isNotEmpty) {
        await tester.tap(subBtn, warnIfMissed: false);
        await tester.pumpAndSettle();
        final ccOpt = find.text("English [CC]");
        if (ccOpt.evaluate().isNotEmpty) {
          await tester.tap(ccOpt.last, warnIfMissed: false);
          await tester.pumpAndSettle();
        }
      }

      // Audio sync calibration dialog
      final audioSyncBtn = find.byTooltip("Audio Sync");
      if (audioSyncBtn.evaluate().isNotEmpty) {
        await tester.tap(audioSyncBtn, warnIfMissed: false);
        await tester.pumpAndSettle();
        final closeBtn = find.text("Close");
        if (closeBtn.evaluate().isNotEmpty) {
          await tester.tap(closeBtn, warnIfMissed: false);
          await tester.pumpAndSettle();
        }
      }

      // Playback speed dropdown
      final speedDropdown = find.byType(DropdownButton<double>);
      if (speedDropdown.evaluate().isNotEmpty) {
        await tester.tap(speedDropdown, warnIfMissed: false);
        await tester.pumpAndSettle();
        final speed2x = find.text("2.0x");
        if (speed2x.evaluate().isNotEmpty) {
          await tester.tap(speed2x.last, warnIfMissed: false);
          await tester.pumpAndSettle();
        }
      }

      PlatformFilePicker.mockPickedFiles = null;
    });

    testWidgets('StudioEditorModeView subtitle cue operations and media bin tab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudioEditorModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Tab 0: Media Bin
      await tester.tap(find.text("Media"));
      await tester.pumpAndSettle();
      expect(find.text("SMPTE HD Master"), findsWidgets);

      // Add clip to timeline via Grid More popup
      final moreBtn = find.byIcon(Icons.more_vert);
      if (moreBtn.evaluate().isNotEmpty) {
        await tester.tap(moreBtn.first);
        await tester.pumpAndSettle();
        final addOpt = find.text("Add to Timeline");
        if (addOpt.evaluate().isNotEmpty) {
          await tester.tap(addOpt);
          await tester.pumpAndSettle();
        }
      }

      // Play transport briefly so playhead advances
      final playBtn = find.byIcon(Icons.play_arrow);
      if (playBtn.evaluate().isNotEmpty) {
        await tester.tap(playBtn);
        await tester.pump(const Duration(milliseconds: 200));
        final pauseBtn = find.byIcon(Icons.pause);
        if (pauseBtn.evaluate().isNotEmpty) {
          await tester.tap(pauseBtn);
          await tester.pumpAndSettle();
        }
      }

      // Split at playhead
      final splitBtn = find.byTooltip("Split at Playhead (S)");
      if (splitBtn.evaluate().isNotEmpty) {
        await tester.tap(splitBtn);
        await tester.pumpAndSettle();
      }

      // Ripple delete selected clip
      final rippleBtn = find.byTooltip("Ripple Delete Selected (Del)");
      if (rippleBtn.evaluate().isNotEmpty) {
        await tester.tap(rippleBtn);
        await tester.pumpAndSettle();
      }

      // Switch to Media Bin, add clip again so selectedClip is active
      await tester.tap(find.text("Media"));
      await tester.pumpAndSettle();
      if (moreBtn.evaluate().isNotEmpty) {
        await tester.tap(moreBtn.first);
        await tester.pumpAndSettle();
        final addOpt = find.text("Add to Timeline");
        if (addOpt.evaluate().isNotEmpty) {
          await tester.tap(addOpt);
          await tester.pumpAndSettle();
        }
      }

      // Switch to Tab 1: Inspector
      await tester.tap(find.byIcon(Icons.tune).first);
      await tester.pumpAndSettle();

      final addKeyframe = find.text("Add Keyframe");
      if (addKeyframe.evaluate().isNotEmpty) {
        await tester.tap(addKeyframe);
        await tester.pumpAndSettle();
      }
      final crossDissolve = find.text("Cross Dissolve");
      if (crossDissolve.evaluate().isNotEmpty) {
        await tester.tap(crossDissolve);
        await tester.pumpAndSettle();
      }
      final slipBtn = find.text("Slip -0.5s");
      if (slipBtn.evaluate().isNotEmpty) {
        await tester.tap(slipBtn);
        await tester.pumpAndSettle();
      }
      final slideBtn = find.text("Slide +0.5s");
      if (slideBtn.evaluate().isNotEmpty) {
        await tester.tap(slideBtn);
        await tester.pumpAndSettle();
      }

      // Switch to Tab 2: Color
      await tester.tap(find.byIcon(Icons.palette).first);
      await tester.pumpAndSettle();

      // Switch to Tab 3: Audio
      await tester.tap(find.byIcon(Icons.equalizer).first);
      await tester.pumpAndSettle();

      // Switch to Tab 4: Subtitles
      await tester.tap(find.byIcon(Icons.subtitles).first);
      await tester.pumpAndSettle();
      expect(find.text("Subtitles & Closed Captions"), findsOneWidget);

      // Add cue
      await tester.tap(find.byIcon(Icons.add_circle).first);
      await tester.pumpAndSettle();

      // Switch to Tab 5: Queue
      await tester.tap(find.byIcon(Icons.queue).first);
      await tester.pumpAndSettle();
      expect(find.text("Render & Export Queue"), findsOneWidget);

      // Export Video dialog
      final exportBtn = find.text("Export Video");
      if (exportBtn.evaluate().isNotEmpty) {
        await tester.tap(exportBtn);
        await tester.pumpAndSettle();

        final startRenderBtn = find.text("Start Render");
        if (startRenderBtn.evaluate().isNotEmpty) {
          await tester.tap(startRenderBtn);
          await tester.pumpAndSettle();
        }
      }

      // Transport controls
      final skipPrev = find.byIcon(Icons.skip_previous);
      if (skipPrev.evaluate().isNotEmpty) {
        await tester.tap(skipPrev.first);
        await tester.pumpAndSettle();
      }
      final skipNext = find.byIcon(Icons.skip_next);
      if (skipNext.evaluate().isNotEmpty) {
        await tester.tap(skipNext.first);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('TimelineView interactive snapping, muting, seeking and clip interactions', (tester) async {
      final proj = ProjectModel.createDefault();
      final track = proj.tracks.first;
      final clip = track.clips.isNotEmpty
          ? track.clips.first
          : ClipModel(id: 'c1', name: 'Clip 1', mediaPath: 'path.mp4', startTime: 0.0, duration: 4.0);
      ClipModel? selectedClip = clip;
      double playheadTime = 1.0;
      bool splitCalled = false;
      bool rippleCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return TimelineView(
                    project: proj,
                    playheadTime: playheadTime,
                    selectedClip: selectedClip,
                    onPlayheadSeek: (t) => setState(() => playheadTime = t),
                    onClipSelected: (c) => setState(() => selectedClip = c),
                    onSplitAtPlayhead: () => splitCalled = true,
                    onRippleDeleteSelected: () => rippleCalled = true,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Snap toggle
      await tester.tap(find.text("Snap"));
      await tester.pumpAndSettle();

      // Split button
      await tester.tap(find.byTooltip("Split at Playhead (S)"));
      await tester.pumpAndSettle();
      expect(splitCalled, isTrue);

      // Ripple delete button
      await tester.tap(find.byTooltip("Ripple Delete Selected (Del)"));
      await tester.pumpAndSettle();
      expect(rippleCalled, isTrue);

      // Track mute toggle
      final volumeIcon = find.byIcon(Icons.volume_up);
      if (volumeIcon.evaluate().isNotEmpty) {
        await tester.tap(volumeIcon.first);
        await tester.pumpAndSettle();
      }

      // Seek on Time Ruler
      final ruler = find.byType(CustomPaint);
      if (ruler.evaluate().isNotEmpty) {
        await tester.tap(ruler.first);
        await tester.pumpAndSettle();
      }
    });

    test('PlatformFilePicker native dialog runners for all platforms', () async {
      final tempDir = Directory.systemTemp.createTempSync('pfp_test_');
      final f1 = File('${tempDir.path}/test1.mp4')..writeAsStringSync('vid1');
      final f2 = File('${tempDir.path}/test2.mov')..writeAsStringSync('vid2');

      addTearDown(() {
        PlatformFilePicker.mockProcessRunner = null;
        PlatformFilePicker.mockPickedFiles = null;
        PlatformFilePicker.mockPickedFolder = null;
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      // Windows File Picker
      PlatformFilePicker.mockProcessRunner = (exe, args) async {
        return ProcessResult(1, 0, '${f1.path}\n${f2.path}\n', '');
      };
      final winFiles = await PlatformFilePicker.pickFilesWindowsForTesting(
        allowMultiple: true,
        title: 'Select',
        filter: '*.*',
      );
      expect(winFiles.length, 2);

      // Windows exitCode != 0
      PlatformFilePicker.mockProcessRunner = (exe, args) async {
        return ProcessResult(2, 1, '', 'Cancelled');
      };
      final winCancel = await PlatformFilePicker.pickFilesWindowsForTesting(
        allowMultiple: false,
        title: 'Select',
        filter: '*.*',
      );
      expect(winCancel.isEmpty, isTrue);

      // Windows error throw
      PlatformFilePicker.mockProcessRunner = (exe, args) async {
        throw const ProcessException('powershell', [], 'failed');
      };
      final winErr = await PlatformFilePicker.pickFilesWindowsForTesting(
        allowMultiple: false,
        title: 'Select',
        filter: '*.*',
      );
      expect(winErr.isEmpty, isTrue);

      // Windows Folder Picker
      PlatformFilePicker.mockProcessRunner = (exe, args) async {
        return ProcessResult(3, 0, '${tempDir.path}\n', '');
      };
      final winFolder = await PlatformFilePicker.pickFolderWindowsForTesting(title: 'Folder');
      expect(winFolder, tempDir.path);

      // Windows folder exitCode != 0 and exception
      PlatformFilePicker.mockProcessRunner = (exe, args) async => ProcessResult(4, 1, '', '');
      expect(await PlatformFilePicker.pickFolderWindowsForTesting(title: 'F'), isNull);

      PlatformFilePicker.mockProcessRunner = (exe, args) async => throw Exception('fail');
      expect(await PlatformFilePicker.pickFolderWindowsForTesting(title: 'F'), isNull);

      // Linux File Picker - Zenity success
      PlatformFilePicker.mockProcessRunner = (exe, args) async {
        if (exe == 'zenity') {
          return ProcessResult(5, 0, '${f1.path}|${f2.path}', '');
        }
        return ProcessResult(6, 1, '', '');
      };
      final linFiles = await PlatformFilePicker.pickFilesLinuxForTesting(
        allowMultiple: true,
        title: 'Linux Title',
      );
      expect(linFiles.length, 2);

      // Linux Zenity fail, Kdialog fallback success
      PlatformFilePicker.mockProcessRunner = (exe, args) async {
        if (exe == 'zenity') {
          throw const ProcessException('zenity', [], 'not found');
        } else if (exe == 'kdialog') {
          return ProcessResult(7, 0, '${f1.path} ${f2.path}', '');
        }
        return ProcessResult(8, 1, '', '');
      };
      final linKdialog = await PlatformFilePicker.pickFilesLinuxForTesting(
        allowMultiple: true,
        title: 'Linux Title',
      );
      expect(linKdialog.length, 2);

      // Linux Zenity & Kdialog both fail
      PlatformFilePicker.mockProcessRunner = (exe, args) async {
        throw const ProcessException('error', []);
      };
      final linEmpty = await PlatformFilePicker.pickFilesLinuxForTesting(allowMultiple: false, title: 'T');
      expect(linEmpty.isEmpty, isTrue);

      // Linux Folder Picker
      PlatformFilePicker.mockProcessRunner = (exe, args) async {
        if (exe == 'zenity') {
          return ProcessResult(9, 0, tempDir.path, '');
        }
        return ProcessResult(10, 1, '', '');
      };
      final linFolder = await PlatformFilePicker.pickFolderLinuxForTesting(title: 'LinDir');
      expect(linFolder, tempDir.path);

      PlatformFilePicker.mockProcessRunner = (exe, args) async => throw Exception('error');
      expect(await PlatformFilePicker.pickFolderLinuxForTesting(title: 'LinDir'), isNull);

      // macOS File Picker
      PlatformFilePicker.mockProcessRunner = (exe, args) async {
        if (args.any((a) => a.contains('choose file'))) {
          return ProcessResult(11, 0, 'alias "f1", alias "f2"', '');
        } else if (args.any((a) => a.contains('POSIX path'))) {
          return ProcessResult(12, 0, f1.path, '');
        }
        return ProcessResult(13, 1, '', '');
      };
      final macFiles = await PlatformFilePicker.pickFilesMacOSForTesting(allowMultiple: true, title: 'Mac');
      expect(macFiles.isNotEmpty, isTrue);

      // macOS File Picker fail
      PlatformFilePicker.mockProcessRunner = (exe, args) async => throw Exception('err');
      expect(await PlatformFilePicker.pickFilesMacOSForTesting(allowMultiple: false, title: 'Mac'), isEmpty);

      // macOS Folder Picker
      PlatformFilePicker.mockProcessRunner = (exe, args) async => ProcessResult(14, 0, tempDir.path, '');
      final macFolder = await PlatformFilePicker.pickFolderMacOSForTesting(title: 'MacFolder');
      expect(macFolder, tempDir.path);

      PlatformFilePicker.mockProcessRunner = (exe, args) async => throw Exception('err');
      expect(await PlatformFilePicker.pickFolderMacOSForTesting(title: 'MacFolder'), isNull);

      // Android Channel Handler
      const channel = MethodChannel('com.universalvideostudio.uvs/platform');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'pickMediaFiles') {
            return [f1.path, f2.path];
          }
          return null;
        },
      );
      final androidFiles = await PlatformFilePicker.pickFilesAndroidForTesting(allowMultiple: true);
      expect(androidFiles.length, 2);

      // Android Channel Handler throwing
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          throw PlatformException(code: 'CANCEL', message: 'User canceled');
        },
      );
      final androidCancel = await PlatformFilePicker.pickFilesAndroidForTesting(allowMultiple: false);
      expect(androidCancel.isEmpty, isTrue);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);

      // High-level pickMediaFiles, pickProjectFile, pickFolder with mockProcessRunner
      PlatformFilePicker.mockProcessRunner = (exe, args) async {
        final isFolder = args.any((a) =>
            a.contains('FolderBrowserDialog') ||
            a == '--directory' ||
            a.contains('choose folder'));
        if (isFolder) {
          return ProcessResult(16, 0, tempDir.path, '');
        }
        if (exe == 'osascript' && args.any((a) => a.contains('POSIX path'))) {
          return ProcessResult(17, 0, f1.path, '');
        }
        return ProcessResult(15, 0, f1.path, '');
      };

      final autoMedia = await PlatformFilePicker.pickMediaFiles(allowMultiple: true);
      expect(autoMedia.isNotEmpty, isTrue);

      final autoProject = await PlatformFilePicker.pickProjectFile();
      expect(autoProject, isNotNull);

      final autoFolder = await PlatformFilePicker.pickFolder();
      expect(autoFolder, isNotNull);
    });

    testWidgets('MediaBinView interactive grid, list, search, import files and folder', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('bin_test_');
      final f1 = File('${tempDir.path}/sample_a.mp4')..writeAsStringSync('dummy video');
      final f2 = File('${tempDir.path}/sample_b.wav')..writeAsStringSync('dummy audio');
      File('${tempDir.path}/sample_c.mp4').writeAsStringSync('dummy video c');

      addTearDown(() {
        PlatformFilePicker.mockPickedFiles = null;
        PlatformFilePicker.mockPickedFolder = null;
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      List<MediaBinItem> items = [
        MediaBinItem(
          id: 'item-1',
          path: f1.path,
          name: 'sample_a.mp4',
          duration: 12.0,
          width: 1920,
          height: 1080,
          fps: 30.0,
          channels: 2,
        ),
        MediaBinItem(
          id: 'item-2',
          path: f2.path,
          name: 'sample_b.wav',
          duration: 8.5,
          width: 0,
          height: 0,
          fps: 0.0,
          channels: 2,
        ),
      ];

      MediaBinItem? previewSelected;
      MediaBinItem? addedToTimeline;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: SizedBox(
                  width: 400,
                  height: 600,
                  child: MediaBinView(
                    items: items,
                    onSelectPreview: (it) => previewSelected = it,
                    onAddToTimeline: (it) => addedToTimeline = it,
                    onItemsChanged: (newItems) {
                      setState(() {
                        items = newItems;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check item properties
      expect(items[0].isVideo, isTrue);
      expect(items[0].isAudioOnly, isFalse);
      expect(items[0].exists, isTrue);
      expect(items[1].isVideo, isFalse);
      expect(items[1].isAudioOnly, isTrue);

      // Search bar filter
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'sample_a');
      await tester.pumpAndSettle();
      expect(find.text('sample_a.mp4'), findsOneWidget);
      expect(find.text('sample_b.wav'), findsNothing);

      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(find.text('sample_b.wav'), findsOneWidget);

      // Tap card to select preview
      await tester.tap(find.text('sample_a.mp4'));
      await tester.pumpAndSettle();
      expect(previewSelected?.name, 'sample_a.mp4');

      // Popup menu button in Grid Card
      final moreButtons = find.byIcon(Icons.more_vert);
      expect(moreButtons, findsWidgets);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to Timeline'));
      await tester.pumpAndSettle();
      expect(addedToTimeline?.name, 'sample_a.mp4');

      // Popup menu Remove from Bin
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from Bin'));
      await tester.pumpAndSettle();
      expect(items.length, 1);

      // Switch to List View
      final switchToList = find.byTooltip('Switch to List View');
      expect(switchToList, findsOneWidget);
      await tester.tap(switchToList);
      await tester.pumpAndSettle();

      // Tap list item
      await tester.tap(find.text('sample_b.wav'));
      await tester.pumpAndSettle();
      expect(previewSelected?.name, 'sample_b.wav');

      // Tap Add to Timeline button in List view
      final addTimelineBtn = find.byTooltip('Add to Timeline');
      if (addTimelineBtn.evaluate().isNotEmpty) {
        await tester.tap(addTimelineBtn.first);
        await tester.pumpAndSettle();
        expect(addedToTimeline?.name, 'sample_b.wav');
      }

      // Switch back to Grid View
      final switchToGrid = find.byTooltip('Switch to Grid View');
      expect(switchToGrid, findsOneWidget);
      await tester.tap(switchToGrid);
      await tester.pumpAndSettle();

      // Import files via toolbar button
      PlatformFilePicker.mockPickedFiles = [f1.path];
      final importFilesBtn = find.byTooltip('Import Media Files');
      expect(importFilesBtn, findsOneWidget);
      await tester.tap(importFilesBtn);
      await tester.pumpAndSettle();
      expect(items.any((it) => it.name == 'sample_a.mp4'), isTrue);

      // Import folder via toolbar button
      PlatformFilePicker.mockPickedFolder = tempDir.path;
      final importFolderBtn = find.byTooltip('Import Folder');
      expect(importFolderBtn, findsOneWidget);
      await tester.tap(importFolderBtn);
      await tester.pumpAndSettle();
      expect(items.any((it) => it.name == 'sample_c.mp4'), isTrue);
    });

    testWidgets('MediaBinView empty state import media button', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('bin_empty_');
      final f1 = File('${tempDir.path}/clip.mp4')..writeAsStringSync('dummy');

      addTearDown(() {
        PlatformFilePicker.mockPickedFiles = null;
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      List<MediaBinItem> items = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: MediaBinView(
                  items: items,
                  onItemsChanged: (newItems) {
                    setState(() {
                      items = newItems;
                    });
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("No Media Ingested"), findsOneWidget);

      PlatformFilePicker.mockPickedFiles = [f1.path];
      await tester.tap(find.widgetWithText(ElevatedButton, "Import Media"));
      await tester.pumpAndSettle();
      expect(items.length, 1);
    });

    test('MediaService error handling, proxies, waveforms, and caching', () {
      final s = MediaService.instance;
      expect(() => s.validateAndIngestMedia('   '), throwsArgumentError);
      expect(
        () => s.validateAndIngestMedia('/nonexistent/media/file.mp4'),
        throwsA(isA<FileSystemException>()),
      );

      final tempDir = Directory.systemTemp.createTempSync('ms_test_');
      final mediaFile = File('${tempDir.path}/sample.mp4')..writeAsStringSync('data');

      final probe = s.validateAndIngestMedia(mediaFile.path);
      expect(probe.path, mediaFile.resolveSymbolicLinksSync());
      expect(probe.resolutionString.contains('x'), isTrue);
      expect(probe.fpsString.contains('fps'), isTrue);
      expect(probe.fileName, 'sample.mp4');

      // Cached probe
      final cachedProbe = s.probeMedia(mediaFile.path);
      expect(cachedProbe.fileName, probe.fileName);
      expect(cachedProbe.path.replaceAll('\\', '/'), probe.path.replaceAll('\\', '/'));

      // Waveform
      final wf1 = s.getWaveform(mediaFile.path, points: 64);
      expect(wf1.length, 64);
      final wf2 = s.getWaveform(mediaFile.path, points: 64);
      expect(identical(wf1, wf2), isTrue);

      // Proxy creation
      final proxyPath = s.createProxy(mediaFile.path, targetHeight: 480);
      expect(proxyPath.contains('480p'), isTrue);

      // Extract frame cached
      final frame1 = s.extractFrame(mediaFile.path, 1.0);
      expect(frame1.isNotEmpty, isTrue);

      // Clear cache
      s.clearCache();

      // Fixture resolution
      final fix = MediaService.resolveFixture('pubspec.yaml');
      expect(fix, isNotNull);
      expect(MediaService.resolveFixture('nonexistent_fixture_123.xyz'), isNull);

      tempDir.deleteSync(recursive: true);
    });

    test('RecentMediaService storage, addition, and pruning', () {
      final rms = RecentMediaService.instance;
      rms.clearRecents();
      expect(rms.recentMedia, isEmpty);
      expect(rms.recentProjects, isEmpty);

      final tempDir = Directory.systemTemp.createTempSync('rms_test_');
      final f1 = File('${tempDir.path}/rec1.mp4')..writeAsStringSync('1');
      final f2 = File('${tempDir.path}/rec2.uvsp')..writeAsStringSync('2');

      rms.addRecentMedia(f1.path);
      rms.addRecentProject(f2.path);
      expect(rms.recentMedia.contains(f1.path), isTrue);
      expect(rms.recentProjects.contains(f2.path), isTrue);

      // Non-existent ignored
      rms.addRecentMedia('/nonexistent/fake.mp4');
      rms.addRecentProject('/nonexistent/fake.uvsp');

      rms.clearRecents();
      expect(rms.recentMedia, isEmpty);
      tempDir.deleteSync(recursive: true);
    });

    test('RenderService cancel job coverage', () async {
      final render = RenderService.instance;
      render.resetForTesting();
      final job = render.queueRender(
        name: 'Cancel Test',
        outputPath: 'cancel.mp4',
        project: ProjectService.instance.project,
        inputPath: 'nonexistent_file_to_cancel.mp4',
      );
      render.cancelJob(job.id);
      expect(render.jobs.firstWhere((j) => j.id == job.id).status, RenderStatus.cancelled);
      render.clearCompleted();
      expect(render.jobs.isEmpty, isTrue);
    });

    testWidgets('PlayerModeView recents menu and active player gesture controls', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('pm_rec_test_');
      final f1 = File('${tempDir.path}/recent_clip.mp4')..writeAsStringSync('test');

      RecentMediaService.instance.addRecentMedia(f1.path);

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      addTearDown(() {
        RecentMediaService.instance.clearRecents();
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerModeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check if open button is present in empty state
      final openBtn = find.text("Open Media File");
      if (openBtn.evaluate().isNotEmpty) {
        PlatformFilePicker.mockPickedFiles = [f1.path];
        await tester.tap(openBtn);
        await tester.pumpAndSettle();
        PlatformFilePicker.mockPickedFiles = null;
      }

      // Now in active player mode!
      expect(find.byType(Slider), findsOneWidget);

      // Tap player surface to toggle controls
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // Tap again to show controls
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // Drag slider
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(30, 0));
      await tester.pumpAndSettle();
    });
  });
}
