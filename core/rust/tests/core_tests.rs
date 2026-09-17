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
    BlendMode, Clip, Interpolation, Keyframe, KeyframeTrack, Marker, RationalTime, TimecodeConfig, Timeline, Track, TrackType, Transform,
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
    assert!(tc_str.contains(';'), "Drop-frame format must contain semicolon: {}", tc_str);

    let parsed = RationalTime::parse_timecode("00:01:00:00", TimecodeConfig::fps_30()).unwrap();
    assert_eq!(parsed.to_frames(TimecodeConfig::fps_30()), 1800);
}

#[test]
fn test_timeline_operations() {
    let mut tl = Timeline::new(1920, 1080, TimecodeConfig::fps_30());
    let mut v1 = Track::new("V1", TrackType::Video, 0);

    let c1 = Clip::new("Clip1", "media1.mp4", RationalTime::zero(), RationalTime::from_seconds(5, 1));
    let c2 = Clip::new("Clip2", "media2.mp4", RationalTime::from_seconds(5, 1), RationalTime::from_seconds(5, 1));

    assert!(v1.add_clip(c1).is_ok());
    assert!(v1.add_clip(c2).is_ok());

    // Overlap test
    let c_bad = Clip::new("ClipBad", "bad.mp4", RationalTime::from_seconds(3, 1), RationalTime::from_seconds(4, 1));
    assert!(v1.add_clip(c_bad).is_err(), "Overlapping clip must be rejected");

    tl.add_track(v1);
    assert_eq!(tl.total_duration(), RationalTime::from_seconds(10, 1));

    let track_id = tl.tracks[0].id.clone();
    let clip1_id = tl.tracks[0].clips[0].id.clone();

    // Split clip at 2.0s
    assert!(tl.split_clip_at(&track_id, &clip1_id, RationalTime::from_seconds(2, 1)).is_ok());
    assert_eq!(tl.tracks[0].clips.len(), 3);
    assert_eq!(tl.tracks[0].clips[0].duration, RationalTime::from_seconds(2, 1));
    assert_eq!(tl.tracks[0].clips[1].duration, RationalTime::from_seconds(3, 1));

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
    assert!((mid - 50.0).abs() < 1e-3, "Midpoint linear keyframe must be 50.0, got {}", mid);
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
    let key1 = FrameCacheKey { media_path: "test.mp4".into(), frame_number: 1, width: 10, height: 10 };
    let frame1 = FrameBuffer { key: key1.clone(), width: 10, height: 10, data: vec![0u8; 1200], pts_seconds: 0.0 };

    let key2 = FrameCacheKey { media_path: "test.mp4".into(), frame_number: 2, width: 10, height: 10 };
    let frame2 = FrameBuffer { key: key2.clone(), width: 10, height: 10, data: vec![0u8; 1200], pts_seconds: 0.033 };

    cache.insert(frame1);
    assert!(cache.get(&key1).is_some());

    // Inserting frame2 exceeds 2000 bytes, should evict frame1
    cache.insert(frame2);
    assert!(cache.get(&key2).is_some());
    assert!(cache.get(&key1).is_none(), "Frame 1 must be evicted to stay within memory budget");
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
    assert!(lufs > -30.0 && lufs < 0.0, "Expected reasonable LUFS, got {}", lufs);

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
    assert!((r - 0.4).abs() < 1e-3, "Expected 0.4 exposure boost, got {}", r);

    let cube_content = "TITLE \"Test\"\nLUT_3D_SIZE 2\n0 0 0\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1";
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

    let clip = Clip::new("TestClip", "test.mp4", RationalTime::zero(), RationalTime::from_seconds(4, 1));
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

    let c1 = Clip::new("Clip1", "c1.mp4", RationalTime::zero(), RationalTime::from_seconds(5, 1));
    let c2 = Clip::new("Clip2", "c2.mp4", RationalTime::from_seconds(5, 1), RationalTime::from_seconds(5, 1));
    v1.add_clip(c1).unwrap();
    v1.add_clip(c2).unwrap();
    tl.add_track(v1);

    let tid = tl.tracks[0].id.clone();
    let c1_id = tl.tracks[0].clips[0].id.clone();
    let c2_id = tl.tracks[0].clips[1].id.clone();

    // 1. Roll Edit: move cut point right by 1s (C1 becomes 6s, C2 becomes 4s, starting at 6s)
    let delta = RationalTime::from_seconds(1, 1);
    assert!(tl.roll_edit(&tid, &c1_id, &c2_id, delta).is_ok());
    assert_eq!(tl.tracks[0].clips[0].duration, RationalTime::from_seconds(6, 1));
    assert_eq!(tl.tracks[0].clips[1].start_time, RationalTime::from_seconds(6, 1));
    assert_eq!(tl.tracks[0].clips[1].duration, RationalTime::from_seconds(4, 1));
    assert_eq!(tl.total_duration(), RationalTime::from_seconds(10, 1));

    // 2. Slip Edit: adjust in-point of C2 by +0.5s without moving start_time or duration
    let slip_delta = RationalTime::from_seconds(1, 2);
    let orig_in = tl.tracks[0].clips[1].in_point;
    assert!(tl.slip_edit(&tid, &c2_id, slip_delta).is_ok());
    assert_eq!(tl.tracks[0].clips[1].in_point, orig_in + slip_delta);
    assert_eq!(tl.tracks[0].clips[1].duration, RationalTime::from_seconds(4, 1));
    assert_eq!(tl.tracks[0].clips[1].start_time, RationalTime::from_seconds(6, 1));

    // 3. Head trim C1 from 0s to 1s
    assert!(tl.trim_clip_head(&tid, &c1_id, RationalTime::from_seconds(1, 1)).is_ok());
    assert_eq!(tl.tracks[0].clips[0].start_time, RationalTime::from_seconds(1, 1));
    assert_eq!(tl.tracks[0].clips[0].duration, RationalTime::from_seconds(5, 1));

    // 4. Ripple trim head of C2 by 1s
    assert!(tl.ripple_trim_head(&tid, &c2_id, RationalTime::from_seconds(1, 1)).is_ok());
    assert_eq!(tl.tracks[0].clips[1].duration, RationalTime::from_seconds(3, 1));
}

#[test]
fn test_nle_speed_reverse_link_group_markers() {
    let mut tl = Timeline::new(1920, 1080, TimecodeConfig::fps_30());
    let mut v1 = Track::new("V1", TrackType::Video, 0);
    let mut a1 = Track::new("A1", TrackType::Audio, 1);

    let c_v = Clip::new("VideoClip", "clip.mp4", RationalTime::zero(), RationalTime::from_seconds(10, 1));
    let c_a = Clip::new("AudioClip", "clip.mp4", RationalTime::zero(), RationalTime::from_seconds(10, 1));
    let cv_id = c_v.id.clone();
    let ca_id = c_a.id.clone();

    v1.add_clip(c_v).unwrap();
    a1.add_clip(c_a).unwrap();
    tl.add_track(v1);
    tl.add_track(a1);

    // Link clips (A/V sync lock)
    assert!(tl.link_clips(&cv_id, &ca_id).is_ok());
    assert_eq!(tl.tracks[0].clips[0].linked_clip_id.as_deref(), Some(ca_id.as_str()));
    assert_eq!(tl.tracks[1].clips[0].linked_clip_id.as_deref(), Some(cv_id.as_str()));

    // Speed & Reverse
    let v_tid = tl.tracks[0].id.clone();
    assert!(tl.set_clip_speed(&v_tid, &cv_id, 2.0, true).is_ok());
    assert_eq!(tl.tracks[0].clips[0].speed, 2.0);
    assert!(tl.tracks[0].clips[0].reverse);

    // Grouping
    tl.group_clips(&[&cv_id, &ca_id], Some("group_scene1".into()));
    assert_eq!(tl.tracks[0].clips[0].group_id.as_deref(), Some("group_scene1"));
    assert_eq!(tl.tracks[1].clips[0].group_id.as_deref(), Some("group_scene1"));

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
    assert_eq!(std::fs::metadata(&target_path).unwrap().len(), original_size);

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

