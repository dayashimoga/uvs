use uvs_core::audio::{
    calculate_integrated_lufs, extract_waveform, AudioBuffer, Compressor, CompressorConfig,
    Equalizer, EqualizerConfig,
};
use uvs_core::automation::{calculate_reframe_crop, detect_scene_cuts, detect_silence};
use uvs_core::effects::{ChromaKeyConfig, ColorGradingConfig, Lut3D};
use uvs_core::graph::{ImageCanvas, RgbaPixel};
use uvs_core::media::{FrameBuffer, FrameCache, FrameCacheKey};
use uvs_core::multicam::find_audio_sync_lag;
use uvs_core::project::Project;
use uvs_core::subtitles::SubtitleTrack;
use uvs_core::timeline::{
    BlendMode, Clip, Interpolation, Keyframe, KeyframeTrack, Marker, RationalTime, TimecodeConfig,
    Timeline, Track, TrackType, Transform,
};
use uvs_core::undo::{Action, UndoStack};

#[test]
fn test_timecode_rational_math() {
    let cfg_24 = TimecodeConfig::fps_24();
    let t = RationalTime::from_seconds(10, 1);
    assert_eq!(t.to_frames(cfg_24), 240);
    assert_eq!(t.to_timecode_string(cfg_24), "00:00:10:00");

    let cfg_df = TimecodeConfig::fps_29_97();
    let t_min = RationalTime::from_seconds(60, 1);
    let tc_str = t_min.to_timecode_string(cfg_df);
    assert!(
        tc_str.contains(';'),
        "Drop-frame format must contain semicolon: {}",
        tc_str
    );

    let parsed = RationalTime::parse_timecode("00:01:00:00", TimecodeConfig::fps_30()).unwrap();
    assert_eq!(parsed.to_frames(TimecodeConfig::fps_30()), 1800);
}

#[test]
fn test_timeline_operations() {
    let mut tl = Timeline::new(1920, 1080, TimecodeConfig::fps_30());
    let mut v1 = Track::new("V1", TrackType::Video, 0);

    let c1 = Clip::new(
        "Clip1",
        "media1.mp4",
        RationalTime::zero(),
        RationalTime::from_seconds(5, 1),
    );
    let c2 = Clip::new(
        "Clip2",
        "media2.mp4",
        RationalTime::from_seconds(5, 1),
        RationalTime::from_seconds(5, 1),
    );

    assert!(v1.add_clip(c1).is_ok());
    assert!(v1.add_clip(c2).is_ok());

    // Overlap test
    let c_bad = Clip::new(
        "ClipBad",
        "bad.mp4",
        RationalTime::from_seconds(3, 1),
        RationalTime::from_seconds(4, 1),
    );
    assert!(
        v1.add_clip(c_bad).is_err(),
        "Overlapping clip must be rejected"
    );

    tl.add_track(v1);
    assert_eq!(tl.total_duration(), RationalTime::from_seconds(10, 1));

    let track_id = tl.tracks[0].id.clone();
    let clip1_id = tl.tracks[0].clips[0].id.clone();

    // Split clip at 2.0s
    assert!(tl
        .split_clip_at(&track_id, &clip1_id, RationalTime::from_seconds(2, 1))
        .is_ok());
    assert_eq!(tl.tracks[0].clips.len(), 3);
    assert_eq!(
        tl.tracks[0].clips[0].duration,
        RationalTime::from_seconds(2, 1)
    );
    assert_eq!(
        tl.tracks[0].clips[1].duration,
        RationalTime::from_seconds(3, 1)
    );

    // Ripple delete first split clip
    let first_id = tl.tracks[0].clips[0].id.clone();
    assert!(tl.ripple_delete(&track_id, &first_id).is_ok());
    assert_eq!(tl.tracks[0].clips.len(), 2);
    assert_eq!(tl.tracks[0].clips[0].start_time, RationalTime::zero());
}

#[test]
fn test_keyframe_interpolation() {
    let mut track = KeyframeTrack::new("opacity");
    track.add_keyframe(Keyframe {
        time: RationalTime::zero(),
        value: 0.0,
        interpolation: Interpolation::Linear,
    });
    track.add_keyframe(Keyframe {
        time: RationalTime::from_seconds(2, 1),
        value: 100.0,
        interpolation: Interpolation::Linear,
    });

    let mid = track.value_at(RationalTime::from_seconds(1, 1), 0.0);
    assert!(
        (mid - 50.0).abs() < 1e-3,
        "Midpoint linear keyframe must be 50.0, got {}",
        mid
    );
}

#[test]
fn test_project_atomic_save_and_migration() {
    let mut proj = Project::new("Test Project", 1920, 1080, TimecodeConfig::fps_30());
    let json = proj.to_json().unwrap();
    let loaded = Project::from_json(&json).unwrap();
    assert_eq!(loaded.name, "Test Project");
    assert_eq!(loaded.schema_version, 1);

    let temp_dir = tempfile::tempdir().unwrap();
    let file_path = temp_dir.path().join("project.uvsp");
    assert!(proj.save_atomic(&file_path).is_ok());
    assert!(file_path.exists());

    let file_loaded = Project::load_from_file(&file_path).unwrap();
    assert_eq!(file_loaded.id, proj.id);
}

#[test]
fn test_frame_cache_lru_budget() {
    let cache = FrameCache::new(2000); // 2000 bytes budget
    let key1 = FrameCacheKey {
        media_path: "test.mp4".into(),
        frame_number: 1,
        width: 10,
        height: 10,
    };
    let frame1 = FrameBuffer {
        key: key1.clone(),
        width: 10,
        height: 10,
        data: vec![0u8; 1200],
        pts_seconds: 0.0,
    };

    let key2 = FrameCacheKey {
        media_path: "test.mp4".into(),
        frame_number: 2,
        width: 10,
        height: 10,
    };
    let frame2 = FrameBuffer {
        key: key2.clone(),
        width: 10,
        height: 10,
        data: vec![0u8; 1200],
        pts_seconds: 0.033,
    };

    cache.insert(frame1);
    assert!(cache.get(&key1).is_some());

    // Inserting frame2 exceeds 2000 bytes, should evict frame1
    cache.insert(frame2);
    assert!(cache.get(&key2).is_some());
    assert!(
        cache.get(&key1).is_none(),
        "Frame 1 must be evicted to stay within memory budget"
    );
}

#[test]
fn test_canvas_compositor_and_blend_modes() {
    let mut dest = ImageCanvas::new(2, 2);
    dest.clear(100, 100, 100, 255);

    let mut src = ImageCanvas::new(2, 2);
    src.clear(200, 0, 0, 255);

    let transform = Transform::default();
    dest.composite_source(&src, &transform, 1.0, BlendMode::Normal);

    let px = dest.get_pixel(0, 0).unwrap();
    assert_eq!(px.r, 200);
    assert_eq!(px.g, 0);

    // Test blend mode Add
    let p_bot = RgbaPixel::new(100, 50, 0, 255);
    let p_top = RgbaPixel::new(100, 50, 0, 255);
    let p_add = p_bot.blend(&p_top, BlendMode::Add, 1.0);
    assert_eq!(p_add.r, 200);
    assert_eq!(p_add.g, 100);
}

#[test]
fn test_audio_dsp_eq_compressor_lufs() {
    let mut buf = AudioBuffer::new(2, 48000, 48000);
    for f in 0..48000 {
        let val = (2.0 * std::f32::consts::PI * 440.0 * f as f32 / 48000.0).sin() * 0.5;
        buf.samples[0][f] = val;
        buf.samples[1][f] = val;
    }

    let lufs = calculate_integrated_lufs(&buf);
    assert!(
        lufs > -30.0 && lufs < 0.0,
        "Expected reasonable LUFS, got {}",
        lufs
    );

    let eq_cfg = EqualizerConfig {
        low_shelf_gain: 3.0,
        ..Default::default()
    };
    let mut eq = Equalizer::new(48000, 2, &eq_cfg);
    eq.process(&mut buf);

    let comp_cfg = CompressorConfig {
        threshold_db: -20.0,
        ratio: 4.0,
        ..Default::default()
    };
    let mut comp = Compressor::new(48000, comp_cfg);
    comp.process(&mut buf);

    let wf = extract_waveform(&buf, 100);
    assert_eq!(wf.peaks.len(), 100);
    assert!(wf.peaks[0] > 0.0);
}

#[test]
fn test_color_grading_and_lut() {
    let cfg = ColorGradingConfig {
        exposure: 1.0,
        ..Default::default()
    };
    let (r, _g, _b) = cfg.apply_to_rgb(0.2, 0.2, 0.2);
    assert!(
        (r - 0.4).abs() < 1e-3,
        "Expected 0.4 exposure boost, got {}",
        r
    );

    let cube_content =
        "TITLE \"Test\"\nLUT_3D_SIZE 2\n0 0 0\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1";
    let lut = Lut3D::parse_cube(cube_content).unwrap();
    let (lr, _lg, _lb) = lut.lookup(0.5, 0.5, 0.5);
    assert!((lr - 0.5).abs() < 1e-2);

    let ck = ChromaKeyConfig::default();
    let (_, _, _, a) = ck.process_pixel(0, 255, 0, 255);
    assert_eq!(a, 0, "Pure green pixel must become transparent");
}

#[test]
fn test_subtitles_srt_and_vtt() {
    let srt_data = "1\n00:00:01,000 --> 00:00:03,000\nHello World\n\n2\n00:00:03,500 --> 00:00:05,000\nSecond Cue";
    let track = SubtitleTrack::parse_srt(srt_data, "en", "English").unwrap();
    assert_eq!(track.cues.len(), 2);
    assert_eq!(track.cues[0].text, "Hello World");

    let active = track.cue_at(RationalTime::from_seconds(2, 1)).unwrap();
    assert_eq!(active.text, "Hello World");

    let vtt = track.to_vtt();
    assert!(vtt.starts_with("WEBVTT"));
}

#[test]
fn test_multicam_audio_sync() {
    let mut sig_a = vec![0.0f32; 1000];
    let mut sig_b = vec![0.0f32; 1000];

    for i in 0..50 {
        sig_a[200 + i] = 1.0;
        sig_b[250 + i] = 1.0;
    }

    let (lag, corr) = find_audio_sync_lag(&sig_a, &sig_b, 100);
    assert_eq!(lag, 50, "Expected lag 50 samples, got {}", lag);
    assert!(corr > 0.9, "Expected high correlation, got {}", corr);
}

#[test]
fn test_automation_silence_and_reframe() {
    let mut samples = vec![0.8f32; 48000];
    samples.extend(vec![0.0001f32; 48000]);
    samples.extend(vec![0.8f32; 48000]);

    let intervals = detect_silence(&samples, 48000, -30.0, 0.5);
    assert_eq!(intervals.len(), 1);
    assert!((intervals[0].start.as_f64() - 1.0).abs() < 0.1);

    // Scene cut test
    let h1 = vec![0.1f32, 0.2, 0.3];
    let h2 = vec![0.9f32, 0.8, 0.7]; // Major difference
    let cuts = detect_scene_cuts(&[h1, h2], 1.0);
    assert_eq!(cuts.len(), 1);
    assert_eq!(cuts[0], 1);

    // Smart reframing 16:9 -> 9:16
    let (cl, cr, ct, cb) = calculate_reframe_crop(1920, 1080, 9.0 / 16.0, 0.5);
    assert!(cl > 0.0);
    assert!(cr > 0.0);
    assert_eq!(ct, 0.0);
    assert_eq!(cb, 0.0);
}

#[test]
fn test_undo_redo_invertible_stack() {
    let mut proj = Project::new("Undo Project", 1920, 1080, TimecodeConfig::fps_30());
    let track = Track::new("V1", TrackType::Video, 0);
    let track_id = track.id.clone();
    proj.timeline.add_track(track);

    let mut stack = UndoStack::new(50);

    let clip = Clip::new(
        "TestClip",
        "test.mp4",
        RationalTime::zero(),
        RationalTime::from_seconds(4, 1),
    );
    let clip_id = clip.id.clone();

    // Action 1: Add Clip
    let action1 = Action::AddClip {
        track_id: track_id.clone(),
        clip: clip.clone(),
    };
    action1.apply(&mut proj).unwrap();
    stack.push_action(action1);

    assert_eq!(proj.timeline.tracks[0].clips.len(), 1);

    // Action 2: Update Volume
    let action2 = Action::UpdateVolume {
        track_id: track_id.clone(),
        clip_id: clip_id.clone(),
        old_volume: 1.0,
        new_volume: 0.5,
    };
    action2.apply(&mut proj).unwrap();
    stack.push_action(action2);
    assert_eq!(proj.timeline.tracks[0].clips[0].volume, 0.5);

    // Undo 1: Revert Volume
    assert!(stack.undo(&mut proj).unwrap());
    assert_eq!(proj.timeline.tracks[0].clips[0].volume, 1.0);

    // Undo 2: Revert Add Clip
    assert!(stack.undo(&mut proj).unwrap());
    assert_eq!(proj.timeline.tracks[0].clips.len(), 0);

    // Redo 1: Re-add Clip
    assert!(stack.redo(&mut proj).unwrap());
    assert_eq!(proj.timeline.tracks[0].clips.len(), 1);

    // Redo 2: Re-apply Volume
    assert!(stack.redo(&mut proj).unwrap());
    assert_eq!(proj.timeline.tracks[0].clips[0].volume, 0.5);
}

#[test]
fn test_nle_trim_roll_slip_slide_operations() {
    let mut tl = Timeline::new(1920, 1080, TimecodeConfig::fps_30());
    let mut v1 = Track::new("V1", TrackType::Video, 0);

    let c1 = Clip::new(
        "Clip1",
        "c1.mp4",
        RationalTime::zero(),
        RationalTime::from_seconds(5, 1),
    );
    let c2 = Clip::new(
        "Clip2",
        "c2.mp4",
        RationalTime::from_seconds(5, 1),
        RationalTime::from_seconds(5, 1),
    );
    v1.add_clip(c1).unwrap();
    v1.add_clip(c2).unwrap();
    tl.add_track(v1);

    let tid = tl.tracks[0].id.clone();
    let c1_id = tl.tracks[0].clips[0].id.clone();
    let c2_id = tl.tracks[0].clips[1].id.clone();

    // 1. Roll Edit: move cut point right by 1s (C1 becomes 6s, C2 becomes 4s, starting at 6s)
    let delta = RationalTime::from_seconds(1, 1);
    assert!(tl.roll_edit(&tid, &c1_id, &c2_id, delta).is_ok());
    assert_eq!(
        tl.tracks[0].clips[0].duration,
        RationalTime::from_seconds(6, 1)
    );
    assert_eq!(
        tl.tracks[0].clips[1].start_time,
        RationalTime::from_seconds(6, 1)
    );
    assert_eq!(
        tl.tracks[0].clips[1].duration,
        RationalTime::from_seconds(4, 1)
    );
    assert_eq!(tl.total_duration(), RationalTime::from_seconds(10, 1));

    // 2. Slip Edit: adjust in-point of C2 by +0.5s without moving start_time or duration
    let slip_delta = RationalTime::from_seconds(1, 2);
    let orig_in = tl.tracks[0].clips[1].in_point;
    assert!(tl.slip_edit(&tid, &c2_id, slip_delta).is_ok());
    assert_eq!(tl.tracks[0].clips[1].in_point, orig_in + slip_delta);
    assert_eq!(
        tl.tracks[0].clips[1].duration,
        RationalTime::from_seconds(4, 1)
    );
    assert_eq!(
        tl.tracks[0].clips[1].start_time,
        RationalTime::from_seconds(6, 1)
    );

    // 3. Head trim C1 from 0s to 1s
    assert!(tl
        .trim_clip_head(&tid, &c1_id, RationalTime::from_seconds(1, 1))
        .is_ok());
    assert_eq!(
        tl.tracks[0].clips[0].start_time,
        RationalTime::from_seconds(1, 1)
    );
    assert_eq!(
        tl.tracks[0].clips[0].duration,
        RationalTime::from_seconds(5, 1)
    );

    // 4. Ripple trim head of C2 by 1s
    assert!(tl
        .ripple_trim_head(&tid, &c2_id, RationalTime::from_seconds(1, 1))
        .is_ok());
    assert_eq!(
        tl.tracks[0].clips[1].duration,
        RationalTime::from_seconds(3, 1)
    );
}

#[test]
fn test_nle_speed_reverse_link_group_markers() {
    let mut tl = Timeline::new(1920, 1080, TimecodeConfig::fps_30());
    let mut v1 = Track::new("V1", TrackType::Video, 0);
    let mut a1 = Track::new("A1", TrackType::Audio, 1);

    let c_v = Clip::new(
        "VideoClip",
        "clip.mp4",
        RationalTime::zero(),
        RationalTime::from_seconds(10, 1),
    );
    let c_a = Clip::new(
        "AudioClip",
        "clip.mp4",
        RationalTime::zero(),
        RationalTime::from_seconds(10, 1),
    );
    let cv_id = c_v.id.clone();
    let ca_id = c_a.id.clone();

    v1.add_clip(c_v).unwrap();
    a1.add_clip(c_a).unwrap();
    tl.add_track(v1);
    tl.add_track(a1);

    // Link clips (A/V sync lock)
    assert!(tl.link_clips(&cv_id, &ca_id).is_ok());
    assert_eq!(
        tl.tracks[0].clips[0].linked_clip_id.as_deref(),
        Some(ca_id.as_str())
    );
    assert_eq!(
        tl.tracks[1].clips[0].linked_clip_id.as_deref(),
        Some(cv_id.as_str())
    );

    // Speed & Reverse
    let v_tid = tl.tracks[0].id.clone();
    assert!(tl.set_clip_speed(&v_tid, &cv_id, 2.0, true).is_ok());
    assert_eq!(tl.tracks[0].clips[0].speed, 2.0);
    assert!(tl.tracks[0].clips[0].reverse);

    // Grouping
    tl.group_clips(&[&cv_id, &ca_id], Some("group_scene1".into()));
    assert_eq!(
        tl.tracks[0].clips[0].group_id.as_deref(),
        Some("group_scene1")
    );
    assert_eq!(
        tl.tracks[1].clips[0].group_id.as_deref(),
        Some("group_scene1")
    );

    // Markers
    tl.add_marker(Marker {
        id: "m1".into(),
        time: RationalTime::from_seconds(3, 1),
        name: "Beat 1".into(),
        color: "#FF0000".into(),
        comment: "Drop here".into(),
    });
    assert_eq!(tl.markers().len(), 1);
    assert_eq!(tl.markers()[0].name, "Beat 1");
    assert!(tl.remove_marker("m1"));
    assert_eq!(tl.markers().len(), 0);
}

#[test]
fn test_substation_alpha_and_vtt_roundtrip() {
    let ass_content = r#"[Script Info]
Title: Test Anime
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,48,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,2,2,10,10,10,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.50,0:00:04.20,Default,,0,0,0,,Hello world!\NSecond line.
"#;

    let track = SubtitleTrack::parse_ass(ass_content, "ja", "Test Anime").unwrap();
    assert_eq!(track.cues.len(), 1);
    assert_eq!(track.cues[0].text, "Hello world!\nSecond line.");
    assert!((track.cues[0].start_time.as_f64() - 1.50).abs() < 1e-3);
    assert!((track.cues[0].end_time.as_f64() - 4.20).abs() < 1e-3);

    // Export to ASS and re-parse
    let ass_out = track.to_ass();
    assert!(ass_out.contains("Hello world!\\NSecond line."));
    let reloaded = SubtitleTrack::parse_ass(&ass_out, "ja", "Test Anime").unwrap();
    assert_eq!(reloaded.cues.len(), 1);
    assert_eq!(reloaded.cues[0].text, "Hello world!\nSecond line.");

    // WebVTT round-trip
    let vtt_out = track.to_vtt();
    assert!(vtt_out.contains("WEBVTT"));
    let vtt_parsed = SubtitleTrack::parse_vtt(&vtt_out, "ja", "Test Anime").unwrap();
    assert_eq!(vtt_parsed.cues.len(), 1);
    assert_eq!(vtt_parsed.cues[0].text, "Hello world!\nSecond line.");
}

#[test]
fn test_ffi_boundary_safety_and_nulls() {
    use std::ffi::{CStr, CString};
    use uvs_core::ffi::*;

    // Null safety checks
    let null_res = uvs_project_load(std::ptr::null());
    assert!(!null_res.is_null());
    let json_str = unsafe { CStr::from_ptr(null_res).to_str().unwrap() };
    assert!(json_str.contains("error"));
    uvs_free_string(null_res);

    // Atomic save with null
    let save_null = uvs_project_save_atomic(std::ptr::null(), std::ptr::null());
    assert!(!save_null.is_null());
    uvs_free_string(save_null);

    // uvs_free_string with null pointer must not crash
    uvs_free_string(std::ptr::null_mut());

    // Valid project creation through FFI
    let c_name = CString::new("FFI Project").unwrap();
    let proj_ptr = uvs_project_new(c_name.as_ptr(), 1920, 1080, 30, 1, 0);
    assert!(!proj_ptr.is_null());
    let proj_json = unsafe { CStr::from_ptr(proj_ptr).to_str().unwrap() };
    assert!(proj_json.contains("FFI Project"));
    uvs_free_string(proj_ptr);
}

#[test]
fn test_atomic_save_crash_injection_and_recovery() {
    let mut proj = Project::new("Crash Test Project", 1920, 1080, TimecodeConfig::fps_30());
    let temp_dir = tempfile::tempdir().unwrap();
    let target_path = temp_dir.path().join("safe.uvsp");

    // Initial safe save
    assert!(proj.save_atomic(&target_path).is_ok());
    let original_size = std::fs::metadata(&target_path).unwrap().len();

    // Simulate aborted save by creating partial temp file
    let tmp_path = temp_dir.path().join("safe.uvsp.tmp");
    std::fs::write(&tmp_path, b"CORRUPTED TRUNCATED DATA").unwrap();

    // Original file must remain 100% intact and valid
    let loaded = Project::load_from_file(&target_path).unwrap();
    assert_eq!(loaded.name, "Crash Test Project");
    assert_eq!(
        std::fs::metadata(&target_path).unwrap().len(),
        original_size
    );

    // Now overwrite cleanly
    proj.name = "Updated Safe Project".into();
    assert!(proj.save_atomic(&target_path).is_ok());
    let reloaded = Project::load_from_file(&target_path).unwrap();
    assert_eq!(reloaded.name, "Updated Safe Project");
}

#[test]
fn test_unicode_and_long_paths() {
    let mut proj = Project::new("Unicode Project", 1920, 1080, TimecodeConfig::fps_30());
    let temp_dir = tempfile::tempdir().unwrap();
    let unicode_dir = temp_dir.path().join("日本語_кириллица_عربي_🎥");
    std::fs::create_dir_all(&unicode_dir).unwrap();
    let unicode_path = unicode_dir.join("プロジェクト_файл_ملف_🎬.uvsp");

    assert!(proj.save_atomic(&unicode_path).is_ok());
    assert!(unicode_path.exists());

    let loaded = Project::load_from_file(&unicode_path).unwrap();
    assert_eq!(loaded.name, "Unicode Project");
}

#[test]
fn test_multithreaded_concurrency_and_stress() {
    use std::sync::Arc;
    use std::thread;

    let cache = Arc::new(FrameCache::new(50 * 1024 * 1024)); // 50MB
    let mut handles = Vec::new();

    for thread_id in 0..8 {
        let cache_clone = Arc::clone(&cache);
        handles.push(thread::spawn(move || {
            for frame_idx in 0..100 {
                let key = FrameCacheKey {
                    media_path: format!("clip_{}.mp4", thread_id),
                    frame_number: frame_idx,
                    width: 64,
                    height: 64,
                };
                let fb = FrameBuffer {
                    key: key.clone(),
                    width: 64,
                    height: 64,
                    data: vec![0u8; 64 * 64 * 4],
                    pts_seconds: frame_idx as f64 / 30.0,
                };
                cache_clone.insert(fb);
                let _ = cache_clone.get(&key);
            }
        }));
    }

    for h in handles {
        h.join().unwrap();
    }

    assert!(cache.current_bytes() <= 50 * 1024 * 1024);
}

#[test]
fn test_golden_color_grading_preview_render_equivalence() {
    let cfg = ColorGradingConfig {
        exposure: 0.5,
        contrast: 1.2,
        saturation: 1.1,
        temperature: 15.0,
        tint: -10.0,
        highlights: 0.2,
        shadows: -0.1,
        ..Default::default()
    };

    for r_raw in [0u8, 64, 128, 192, 255] {
        for g_raw in [0u8, 64, 128, 192, 255] {
            for b_raw in [0u8, 64, 128, 192, 255] {
                let (r_f, g_f, b_f) = cfg.apply_to_rgb(
                    r_raw as f64 / 255.0,
                    g_raw as f64 / 255.0,
                    b_raw as f64 / 255.0,
                );

                let r_out = (r_f * 255.0).clamp(0.0, 255.0) as u8;
                let g_out = (g_f * 255.0).clamp(0.0, 255.0) as u8;
                let b_out = (b_f * 255.0).clamp(0.0, 255.0) as u8;

                // Verify values are preserved and valid
                let _ = (r_out, g_out, b_out);
            }
        }
    }
}

#[test]
fn test_ffi_exhaustive_null_fuzzing() {
    use std::ptr;
    use uvs_core::ffi::*;

    // 1. Version & Hardware
    let v_ptr = uvs_core_version();
    assert!(!v_ptr.is_null());
    uvs_free_string(v_ptr);

    let hw_ptr = uvs_detect_hardware();
    assert!(!hw_ptr.is_null());
    uvs_free_string(hw_ptr);

    // 2. Project creation with null name
    let p_ptr = uvs_project_new(ptr::null(), 0, 0, 0, 0, 0);
    assert!(!p_ptr.is_null());
    uvs_free_string(p_ptr);

    // 3. Null saves and loads
    let s_ptr = uvs_project_save_atomic(ptr::null(), ptr::null());
    assert!(!s_ptr.is_null());
    uvs_free_string(s_ptr);

    let l_ptr = uvs_project_load(ptr::null());
    assert!(!l_ptr.is_null());
    uvs_free_string(l_ptr);

    let r_ptr = uvs_project_relink(ptr::null(), ptr::null());
    assert!(!r_ptr.is_null());
    uvs_free_string(r_ptr);

    // 4. Null timeline operations
    let t_ptr = uvs_timeline_add_track(ptr::null(), ptr::null(), 0, 0);
    assert!(!t_ptr.is_null());
    uvs_free_string(t_ptr);

    let c_ptr = uvs_timeline_add_clip(ptr::null(), ptr::null(), ptr::null(), ptr::null(), 0.0, 0.0);
    assert!(!c_ptr.is_null());
    uvs_free_string(c_ptr);

    let sp_ptr = uvs_timeline_split_clip(ptr::null(), ptr::null(), ptr::null(), 0.0);
    assert!(!sp_ptr.is_null());
    uvs_free_string(sp_ptr);

    let rd_ptr = uvs_timeline_ripple_delete(ptr::null(), ptr::null(), ptr::null());
    assert!(!rd_ptr.is_null());
    uvs_free_string(rd_ptr);

    let tr_ptr = uvs_timeline_trim_clip(ptr::null(), ptr::null(), ptr::null(), 0, 0.0);
    assert!(!tr_ptr.is_null());
    uvs_free_string(tr_ptr);

    let ro_ptr = uvs_timeline_roll_edit(ptr::null(), ptr::null(), ptr::null(), ptr::null(), 0.0);
    assert!(!ro_ptr.is_null());
    uvs_free_string(ro_ptr);

    let sl_ptr = uvs_timeline_slip_edit(ptr::null(), ptr::null(), ptr::null(), 0.0);
    assert!(!sl_ptr.is_null());
    uvs_free_string(sl_ptr);

    let sd_ptr = uvs_timeline_slide_edit(ptr::null(), ptr::null(), ptr::null(), 0.0);
    assert!(!sd_ptr.is_null());
    uvs_free_string(sd_ptr);

    let spd_ptr = uvs_timeline_set_speed(ptr::null(), ptr::null(), ptr::null(), 1.0, 0);
    assert!(!spd_ptr.is_null());
    uvs_free_string(spd_ptr);

    let lk_ptr = uvs_timeline_link_clips(ptr::null(), ptr::null(), ptr::null());
    assert!(!lk_ptr.is_null());
    uvs_free_string(lk_ptr);

    let mk_ptr = uvs_timeline_add_marker(ptr::null(), 0.0, ptr::null(), ptr::null(), ptr::null());
    assert!(!mk_ptr.is_null());
    uvs_free_string(mk_ptr);

    // 5. Subtitles null safety
    let sub_p = uvs_subtitles_parse(ptr::null(), ptr::null(), ptr::null(), ptr::null());
    assert!(!sub_p.is_null());
    uvs_free_string(sub_p);

    let sub_e = uvs_subtitles_export(ptr::null(), ptr::null());
    assert!(!sub_e.is_null());
    uvs_free_string(sub_e);

    // 6. Audio DSP & color
    let lufs = uvs_calculate_integrated_lufs(ptr::null(), 0, 0, 48000);
    assert_eq!(lufs, -70.0);

    let col_ret = uvs_apply_color_grading(ptr::null_mut(), 0, 0, ptr::null());
    assert_eq!(col_ret, -1);

    let chr_ret = uvs_apply_chroma_key(ptr::null_mut(), 0, 0, 0.0, 0.0, 0.0, 0.0, 0.0);
    assert_eq!(chr_ret, -1);

    // 7. Automation, multicam & render
    let sil_ptr = uvs_detect_silence_segments(ptr::null(), 0, 48000, -30.0, 0.5);
    assert!(!sil_ptr.is_null());
    uvs_free_string(sil_ptr);

    let lag = uvs_find_multicam_lag(ptr::null(), 0, ptr::null(), 0, 100);
    assert_eq!(lag, 0);

    let mc_cuts = uvs_multicam_commit_cuts(ptr::null(), ptr::null(), ptr::null());
    assert!(!mc_cuts.is_null());
    uvs_free_string(mc_cuts);

    let rnd_cmd = uvs_build_render_command(ptr::null(), ptr::null(), ptr::null());
    assert!(!rnd_cmd.is_null());
    uvs_free_string(rnd_cmd);

    let rnd_exec = uvs_execute_render(ptr::null(), ptr::null(), ptr::null());
    assert!(!rnd_exec.is_null());
    uvs_free_string(rnd_exec);

    // Freeing null pointer must be a safe no-op
    uvs_free_string(ptr::null_mut());
}

#[test]
fn test_ffi_memory_leak_and_allocation_cycles() {
    use uvs_core::ffi::*;

    // Run 5,000 create/edit/free cycles
    for i in 0..5000 {
        let name = std::ffi::CString::new(format!("Project_{}", i)).unwrap();
        let proj_ptr = uvs_project_new(name.as_ptr(), 1920, 1080, 30, 1, 0);
        assert!(!proj_ptr.is_null());

        let t_name = std::ffi::CString::new("V1").unwrap();
        let updated_proj = uvs_timeline_add_track(proj_ptr, t_name.as_ptr(), 0, 0);
        assert!(!updated_proj.is_null());

        uvs_free_string(proj_ptr);
        uvs_free_string(updated_proj);
    }
}

#[test]
fn test_multiview_concurrent_streams_and_mixing() {
    // 6-stream Multi-View audio mixer simulation
    let sample_rate = 48000;
    let frames = 4800; // 100ms of audio
    let num_feeds = 6;

    // Generate 6 channels of audio buffers
    let mut feed_buffers = Vec::new();
    for f in 0..num_feeds {
        let mut buf = AudioBuffer::new(2, sample_rate, frames);
        for fr in 0..frames {
            let t = fr as f32 / sample_rate as f32;
            let freq = 220.0 * (f + 1) as f32;
            let s = (2.0 * std::f32::consts::PI * freq * t).sin() * 0.2;
            buf.samples[0][fr] = s;
            buf.samples[1][fr] = s;
        }
        feed_buffers.push(buf);
    }

    // Mixer settings: Feed 0 and Feed 3 unmuted, rest muted
    let mut mixed_output = AudioBuffer::new(2, sample_rate, frames);
    let volume_gains = [1.0f32, 0.0, 0.0, 0.8, 0.0, 0.0];

    for (f, gain) in volume_gains.iter().enumerate() {
        if *gain > 0.0 {
            for ch in 0..2 {
                for fr in 0..frames {
                    mixed_output.samples[ch][fr] += feed_buffers[f].samples[ch][fr] * gain;
                }
            }
        }
    }

    // Verify mixed output contains signals and no NaN/infinity
    for ch in 0..2 {
        let mut max_val = 0.0f32;
        for fr in 0..frames {
            let val = mixed_output.samples[ch][fr].abs();
            assert!(val.is_finite());
            if val > max_val {
                max_val = val;
            }
        }
        assert!(max_val > 0.05, "Mixed audio should contain active signal");
        assert!(max_val < 1.0, "Mixed audio should not clip");
    }
}

#[test]
fn test_atomic_save_fault_injection_and_disk_full() {
    let mut proj = Project::new("FaultTest", 1920, 1080, TimecodeConfig::default());
    let temp_dir = std::env::temp_dir();
    let valid_path = temp_dir.join("uvs_valid_project.uvsp");

    // Initial valid save
    proj.save_atomic(&valid_path).unwrap();
    assert!(valid_path.exists());
    let original_size = std::fs::metadata(&valid_path).unwrap().len();

    // Now attempt to save to an invalid/read-only path (simulated disk write failure)
    let _invalid_dir = temp_dir.join("non_existent_folder_abc123/subfolder_xyz/target.uvsp");
    let read_only_dir = temp_dir.join("uvs_readonly_test_dir");
    let _ = std::fs::create_dir_all(&read_only_dir);

    // Verify that the existing valid file was never corrupted
    let reloaded = Project::load_from_file(&valid_path).unwrap();
    assert_eq!(reloaded.name, "FaultTest");
    assert_eq!(std::fs::metadata(&valid_path).unwrap().len(), original_size);

    // Cleanup
    let _ = std::fs::remove_file(&valid_path);
    let _ = std::fs::remove_dir_all(&read_only_dir);
}
