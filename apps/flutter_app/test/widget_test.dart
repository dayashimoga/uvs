import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_video_studio/main.dart';
import 'package:universal_video_studio/src/core/timecode.dart';
import 'package:universal_video_studio/src/models/project_model.dart';
import 'package:universal_video_studio/src/models/render_job_model.dart';
import 'package:universal_video_studio/src/services/project_service.dart';
import 'package:universal_video_studio/src/services/media_service.dart';
import 'package:universal_video_studio/src/services/render_service.dart';
import 'package:universal_video_studio/src/services/recording_service.dart';

void main() {
  test('TimecodeHelper accurately computes frames and formats SMPTE string', () {
    const helper = TimecodeHelper(fpsNum: 30, fpsDen: 1, dropFrame: false);
    expect(helper.secondsToFrames(1.0), 30);
    expect(helper.formatTimecode(10.0), '00:00:10:00');
    expect(TimecodeHelper.formatDurationSeconds(65.5), '01:05.5');
  });

  test('ProjectModel and TrackModel hierarchy operations', () {
    final proj = ProjectModel.createDefault();
    expect(proj.tracks.length, 3);
    expect(proj.duration, 4.0);

    final clip = proj.tracks[0].clips[0];
    expect(clip.containsTime(2.0), isTrue);
    expect(clip.containsTime(5.0), isFalse);

    // Clone and move clip
    final cloned = clip.clone(newStart: 4.0);
    expect(cloned.startTime, 4.0);
    expect(cloned.endTime, 8.0);
  });

  testWidgets('App launches in Player Mode and can switch modes', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const UniversalVideoStudioApp());
    await tester.pumpAndSettle();

    // Check title
    expect(find.text('Universal Video Studio'), findsOneWidget);
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Multi-View'), findsOneWidget);
    expect(find.text('Quick Edit'), findsOneWidget);
    expect(find.text('Studio Editor'), findsOneWidget);
    expect(find.text('Multicam'), findsOneWidget);

    // Switch to Multi-View Mode
    await tester.tap(find.text('Multi-View'));
    await tester.pumpAndSettle();
    expect(find.text('Multi-View Monitoring'), findsOneWidget);

    // Switch to Quick Edit Mode
    await tester.tap(find.text('Quick Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Adjustments'), findsOneWidget);

    // Switch to Studio Editor Mode
    await tester.tap(find.text('Studio Editor'));
    await tester.pumpAndSettle();
    expect(find.text('Export Video'), findsOneWidget);
    expect(find.text('Snap'), findsOneWidget);

    // Switch to Multicam Mode
    await tester.tap(find.text('Multicam'));
    await tester.pumpAndSettle();
    expect(find.text('Multicam Synchronized Switching'), findsOneWidget);
  });

  testWidgets('Studio Editor performs split and ripple delete', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const UniversalVideoStudioApp());
    await tester.pumpAndSettle();

    // Navigate to Studio Editor
    await tester.tap(find.text('Studio Editor'));
    await tester.pumpAndSettle();

    // Tap Split icon
    final splitBtn = find.byTooltip('Split at Playhead (S)');
    expect(splitBtn, findsOneWidget);
    await tester.tap(splitBtn);
    await tester.pumpAndSettle();

    // Tap Ripple Delete icon
    final deleteBtn = find.byTooltip('Ripple Delete Selected (Del)');
    expect(deleteBtn, findsOneWidget);
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();
  });

  testWidgets('Responsive Mobile Layout renders BottomNavigationBar', (WidgetTester tester) async {
    // Set to mobile phone screen (400x800)
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const UniversalVideoStudioApp());
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  test('ProjectService creates, adds tracks, clips, splits, and saves atomic', () {
    final service = ProjectService.instance;
    service.newProject(name: 'Service Test Project');
    expect(service.project['name'], 'Service Test Project');
    expect(service.isDirty, isFalse);

    service.addTrack('Voiceover', 'Audio', 2);
    expect(service.isDirty, isTrue);

    final tracks = service.project['timeline']['tracks'] as List<dynamic>;
    final trackId = tracks.last['id'] as String;

    service.addClip(trackId, 'VO Clip', 'vo.wav', 0.0, 10.0);
    final clips = tracks.last['clips'] as List<dynamic>;
    expect(clips.length, 1);
    final clipId = clips[0]['id'] as String;

    service.splitClip(trackId, clipId, 4.0);
    expect(clips.length, 2);

    service.rippleDelete(trackId, clips[0]['id'] as String);
    expect(clips.length, 1);
    expect(clips[0]['start_time'], 0.0);
  });

  test('MediaService probe and waveform generation', () {
    final media = MediaService.instance;
    final probe = media.probeMedia('sample.mp4');
    expect(probe.width, 1920);
    expect(probe.height, 1080);
    expect(probe.fps, 30.0);

    final waveform = media.getWaveform('sample.mp4', points: 50);
    expect(waveform.length, 50);
    expect(waveform.first, greaterThan(0.0));

    final proxy = media.createProxy('sample.mp4', targetHeight: 720);
    expect(proxy.contains('720p'), isTrue);
  });

  test('RenderService job queue and cancellation', () {
    final render = RenderService.instance;
    render.clearCompleted();

    final project = ProjectService.instance.project;
    final job = render.queueRender(
      name: 'Test Render Job',
      outputPath: 'test_render.mp4',
      project: project,
      inputPath: 'test_input.mp4',
    );

    expect(job.name, 'Test Render Job');
    expect(render.jobs.length, greaterThanOrEqualTo(1));

    render.cancelJob(job.id);
    final cancelled = render.jobs.firstWhere((j) => j.id == job.id);
    expect(cancelled.status, RenderStatus.cancelled);
  });

  test('RecordingService start, toggle sources, and stop', () {
    final rec = RecordingService.instance;
    expect(rec.isRecording, isFalse);

    rec.toggleSource(RecordingSource.camera);
    expect(rec.activeSources.contains(RecordingSource.camera), isTrue);

    final started = rec.startRecording();
    expect(started, isTrue);
    expect(rec.isRecording, isTrue);

    final out = rec.stopRecording();
    expect(out.endsWith('.mp4'), isTrue);
    expect(rec.isRecording, isFalse);
  });

  testWidgets('Player Mode HUD controls and gestures', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const UniversalVideoStudioApp());
    await tester.pumpAndSettle();

    // Verify Player Play/Pause and Seek Bar
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_circle_filled));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Forward 1 frame
    final fwdBtn = find.byTooltip('Next Frame (Right Arrow)');
    expect(fwdBtn, findsOneWidget);
    await tester.tap(fwdBtn);
    await tester.pumpAndSettle();

    // Tap Backward 1 frame
    final backBtn = find.byTooltip('Previous Frame (Left Arrow)');
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();
  });

  testWidgets('Recording Dialog opens and validates sources', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const UniversalVideoStudioApp());
    await tester.pumpAndSettle();

    // Find record action button in top bar
    final recBtn = find.byIcon(Icons.fiber_manual_record);
    expect(recBtn, findsOneWidget);
    await tester.tap(recBtn);
    await tester.pumpAndSettle();

    expect(find.text('Screen & Camera Recording'), findsOneWidget);
    expect(find.text('Start Recording'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Responsive Tablet Layout (800x1280)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const UniversalVideoStudioApp());
    await tester.pumpAndSettle();

    expect(find.text('Universal Video Studio'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
