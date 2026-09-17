import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_video_studio/main.dart';
import 'package:universal_video_studio/src/core/timecode.dart';
import 'package:universal_video_studio/src/models/clip_model.dart';
import 'package:universal_video_studio/src/models/project_model.dart';
import 'package:universal_video_studio/src/models/track_model.dart';

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
}
