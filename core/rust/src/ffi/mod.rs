use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_uint};
use std::path::Path;
use std::panic::catch_unwind;

use crate::audio::{calculate_integrated_lufs, extract_waveform, AudioBuffer};
use crate::automation::detect_silence;
use crate::effects::{ChromaKeyConfig, ColorGradingConfig};
use crate::multicam::find_audio_sync_lag;
use crate::project::Project;
use std::path::PathBuf;
use crate::render::{build_ffmpeg_render_args, execute_ffmpeg_render, HardwareCapabilities};
use crate::subtitles::SubtitleTrack;
use crate::timeline::{Clip, Marker, RationalTime, TimecodeConfig, Track, TrackType};

fn to_c_string(s: impl AsRef<str>) -> *mut c_char {
    CString::new(s.as_ref()).unwrap_or_else(|_| CString::new("").unwrap()).into_raw()
}

fn err_json(msg: &str) -> *mut c_char {
    let escaped = serde_json::to_string(msg).unwrap_or_else(|_| "\"error\"".into());
    to_c_string(format!("{{\"error\": {}}}", escaped))
}

#[no_mangle]
pub extern "C" fn uvs_core_version() -> *mut c_char {
    to_c_string("0.1.0-production")
}

#[no_mangle]
pub extern "C" fn uvs_detect_hardware() -> *mut c_char {
    let caps = HardwareCapabilities::detect();
    let json = serde_json::to_string(&caps).unwrap_or_else(|_| "{}".into());
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn uvs_project_new(
    name: *const c_char,
    width: c_uint,
    height: c_uint,
    fps_num: i64,
    fps_den: i64,
    drop_frame: c_int,
) -> *mut c_char {
    let res = catch_unwind(|| {
        let name_str = if name.is_null() {
            "Untitled Project"
        } else {
            unsafe { CStr::from_ptr(name).to_str().unwrap_or("Untitled Project") }
        };

        let config = TimecodeConfig {
            num: if fps_num > 0 { fps_num } else { 30 },
            den: if fps_den > 0 { fps_den } else { 1 },
            drop_frame: drop_frame != 0,
        };

        let proj = Project::new(name_str, width.max(1), height.max(1), config);
        proj.to_json().unwrap_or_else(|_| "{}".into())
    });

    match res {
        Ok(json) => to_c_string(json),
        Err(_) => err_json("Panic during project creation"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_project_save_atomic(project_json: *const c_char, target_path: *const c_char) -> *mut c_char {
    if project_json.is_null() || target_path.is_null() {
        return err_json("Null argument to uvs_project_save_atomic");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let path_str = unsafe { CStr::from_ptr(target_path).to_str().unwrap_or("") };

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                match proj.save_atomic(Path::new(path_str)) {
                    Ok(_) => "{\"status\": \"ok\"}".to_string(),
                    Err(e) => format!("{{\"error\": \"{}\"}}", e),
                }
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(json) => to_c_string(json),
        Err(_) => err_json("Panic during project atomic save"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_project_load(path: *const c_char) -> *mut c_char {
    if path.is_null() {
        return err_json("Null path in uvs_project_load");
    }

    let res = catch_unwind(|| {
        let path_str = unsafe { CStr::from_ptr(path).to_str().unwrap_or("") };
        match Project::load_from_file(Path::new(path_str)) {
            Ok(proj) => proj.to_json().unwrap_or_else(|_| "{}".into()),
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(json) => to_c_string(json),
        Err(_) => err_json("Panic during project load"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_project_relink(project_json: *const c_char, search_dir: *const c_char) -> *mut c_char {
    if project_json.is_null() || search_dir.is_null() {
        return err_json("Null pointer to uvs_project_relink");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let dir_str = unsafe { CStr::from_ptr(search_dir).to_str().unwrap_or("") };

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                let relinked = proj.relink_missing_assets(&[PathBuf::from(dir_str)]);
                let new_json = proj.to_json().unwrap_or_else(|_| "{}".into());
                format!("{{\"relinked_count\": {}, \"project\": {}}}", relinked.len(), new_json)
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic during asset relinking"),
    }
}

// -------------------- Timeline Operations --------------------

#[no_mangle]
pub extern "C" fn uvs_timeline_add_track(
    project_json: *const c_char,
    name: *const c_char,
    track_type: c_int,
    z_index: c_int,
) -> *mut c_char {
    if project_json.is_null() {
        return err_json("Null project_json");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let track_name = if name.is_null() {
            "Track"
        } else {
            unsafe { CStr::from_ptr(name).to_str().unwrap_or("Track") }
        };

        let t_type = match track_type {
            0 => TrackType::Video,
            1 => TrackType::Audio,
            2 => TrackType::Subtitle,
            _ => TrackType::Adjustment,
        };

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                let track = Track::new(track_name, t_type, z_index);
                proj.timeline.add_track(track);
                proj.to_json().unwrap_or_else(|_| "{}".into())
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_timeline_add_track"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_timeline_add_clip(
    project_json: *const c_char,
    track_id: *const c_char,
    clip_name: *const c_char,
    media_path: *const c_char,
    start_s: f64,
    duration_s: f64,
) -> *mut c_char {
    if project_json.is_null() || track_id.is_null() || clip_name.is_null() || media_path.is_null() {
        return err_json("Null argument to uvs_timeline_add_clip");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let tid = unsafe { CStr::from_ptr(track_id).to_str().unwrap_or("") };
        let name = unsafe { CStr::from_ptr(clip_name).to_str().unwrap_or("Clip") };
        let path = unsafe { CStr::from_ptr(media_path).to_str().unwrap_or("") };

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                let start_time = RationalTime::from_f64(start_s);
                let duration = RationalTime::from_f64(duration_s);
                let clip = Clip::new(name, path, start_time, duration);

                if let Some(track) = proj.timeline.tracks.iter_mut().find(|t| t.id == tid) {
                    match track.add_clip(clip) {
                        Ok(_) => proj.to_json().unwrap_or_else(|_| "{}".into()),
                        Err(e) => format!("{{\"error\": \"{}\"}}", e),
                    }
                } else {
                    format!("{{\"error\": \"Track not found: {}\"}}", tid)
                }
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_timeline_add_clip"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_timeline_split_clip(
    project_json: *const c_char,
    track_id: *const c_char,
    clip_id: *const c_char,
    split_time_s: f64,
) -> *mut c_char {
    if project_json.is_null() || track_id.is_null() || clip_id.is_null() {
        return err_json("Null argument to uvs_timeline_split_clip");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let tid = unsafe { CStr::from_ptr(track_id).to_str().unwrap_or("") };
        let cid = unsafe { CStr::from_ptr(clip_id).to_str().unwrap_or("") };
        let split_time = RationalTime::from_f64(split_time_s);

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                match proj.timeline.split_clip_at(tid, cid, split_time) {
                    Ok(_) => proj.to_json().unwrap_or_else(|_| "{}".into()),
                    Err(e) => format!("{{\"error\": \"{}\"}}", e),
                }
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_timeline_split_clip"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_timeline_ripple_delete(
    project_json: *const c_char,
    track_id: *const c_char,
    clip_id: *const c_char,
) -> *mut c_char {
    if project_json.is_null() || track_id.is_null() || clip_id.is_null() {
        return err_json("Null argument to uvs_timeline_ripple_delete");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let tid = unsafe { CStr::from_ptr(track_id).to_str().unwrap_or("") };
        let cid = unsafe { CStr::from_ptr(clip_id).to_str().unwrap_or("") };

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                match proj.timeline.ripple_delete(tid, cid) {
                    Ok(_) => proj.to_json().unwrap_or_else(|_| "{}".into()),
                    Err(e) => format!("{{\"error\": \"{}\"}}", e),
                }
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_timeline_ripple_delete"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_timeline_trim_clip(
    project_json: *const c_char,
    track_id: *const c_char,
    clip_id: *const c_char,
    is_head: c_int,
    new_time_s: f64,
) -> *mut c_char {
    if project_json.is_null() || track_id.is_null() || clip_id.is_null() {
        return err_json("Null argument to uvs_timeline_trim_clip");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let tid = unsafe { CStr::from_ptr(track_id).to_str().unwrap_or("") };
        let cid = unsafe { CStr::from_ptr(clip_id).to_str().unwrap_or("") };
        let target_time = RationalTime::from_f64(new_time_s);

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                let res = if is_head != 0 {
                    proj.timeline.trim_clip_head(tid, cid, target_time)
                } else {
                    proj.timeline.trim_clip_tail(tid, cid, target_time)
                };

                match res {
                    Ok(_) => proj.to_json().unwrap_or_else(|_| "{}".into()),
                    Err(e) => format!("{{\"error\": \"{}\"}}", e),
                }
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_timeline_trim_clip"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_timeline_roll_edit(
    project_json: *const c_char,
    track_id: *const c_char,
    left_clip_id: *const c_char,
    right_clip_id: *const c_char,
    delta_s: f64,
) -> *mut c_char {
    if project_json.is_null() || track_id.is_null() || left_clip_id.is_null() || right_clip_id.is_null() {
        return err_json("Null argument to uvs_timeline_roll_edit");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let tid = unsafe { CStr::from_ptr(track_id).to_str().unwrap_or("") };
        let l_cid = unsafe { CStr::from_ptr(left_clip_id).to_str().unwrap_or("") };
        let r_cid = unsafe { CStr::from_ptr(right_clip_id).to_str().unwrap_or("") };
        let delta = RationalTime::from_f64(delta_s);

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                match proj.timeline.roll_edit(tid, l_cid, r_cid, delta) {
                    Ok(_) => proj.to_json().unwrap_or_else(|_| "{}".into()),
                    Err(e) => format!("{{\"error\": \"{}\"}}", e),
                }
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_timeline_roll_edit"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_timeline_slip_edit(
    project_json: *const c_char,
    track_id: *const c_char,
    clip_id: *const c_char,
    delta_s: f64,
) -> *mut c_char {
    if project_json.is_null() || track_id.is_null() || clip_id.is_null() {
        return err_json("Null argument to uvs_timeline_slip_edit");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let tid = unsafe { CStr::from_ptr(track_id).to_str().unwrap_or("") };
        let cid = unsafe { CStr::from_ptr(clip_id).to_str().unwrap_or("") };
        let delta = RationalTime::from_f64(delta_s);

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                match proj.timeline.slip_edit(tid, cid, delta) {
                    Ok(_) => proj.to_json().unwrap_or_else(|_| "{}".into()),
                    Err(e) => format!("{{\"error\": \"{}\"}}", e),
                }
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_timeline_slip_edit"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_timeline_slide_edit(
    project_json: *const c_char,
    track_id: *const c_char,
    clip_id: *const c_char,
    delta_s: f64,
) -> *mut c_char {
    if project_json.is_null() || track_id.is_null() || clip_id.is_null() {
        return err_json("Null argument to uvs_timeline_slide_edit");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let tid = unsafe { CStr::from_ptr(track_id).to_str().unwrap_or("") };
        let cid = unsafe { CStr::from_ptr(clip_id).to_str().unwrap_or("") };
        let delta = RationalTime::from_f64(delta_s);

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                match proj.timeline.slide_edit(tid, cid, delta) {
                    Ok(_) => proj.to_json().unwrap_or_else(|_| "{}".into()),
                    Err(e) => format!("{{\"error\": \"{}\"}}", e),
                }
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_timeline_slide_edit"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_timeline_set_speed(
    project_json: *const c_char,
    track_id: *const c_char,
    clip_id: *const c_char,
    speed: f64,
    reverse: c_int,
) -> *mut c_char {
    if project_json.is_null() || track_id.is_null() || clip_id.is_null() {
        return err_json("Null argument to uvs_timeline_set_speed");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let tid = unsafe { CStr::from_ptr(track_id).to_str().unwrap_or("") };
        let cid = unsafe { CStr::from_ptr(clip_id).to_str().unwrap_or("") };

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                match proj.timeline.set_clip_speed(tid, cid, speed, reverse != 0) {
                    Ok(_) => proj.to_json().unwrap_or_else(|_| "{}".into()),
                    Err(e) => format!("{{\"error\": \"{}\"}}", e),
                }
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_timeline_set_speed"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_timeline_link_clips(
    project_json: *const c_char,
    clip1_id: *const c_char,
    clip2_id: *const c_char,
) -> *mut c_char {
    if project_json.is_null() || clip1_id.is_null() || clip2_id.is_null() {
        return err_json("Null argument to uvs_timeline_link_clips");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let c1 = unsafe { CStr::from_ptr(clip1_id).to_str().unwrap_or("") };
        let c2 = unsafe { CStr::from_ptr(clip2_id).to_str().unwrap_or("") };

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                match proj.timeline.link_clips(c1, c2) {
                    Ok(_) => proj.to_json().unwrap_or_else(|_| "{}".into()),
                    Err(e) => format!("{{\"error\": \"{}\"}}", e),
                }
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_timeline_link_clips"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_timeline_add_marker(
    project_json: *const c_char,
    time_s: f64,
    name: *const c_char,
    color: *const c_char,
    comment: *const c_char,
) -> *mut c_char {
    if project_json.is_null() {
        return err_json("Null project_json");
    }

    let res = catch_unwind(|| {
        let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let marker_name = if name.is_null() { "Marker" } else { unsafe { CStr::from_ptr(name).to_str().unwrap_or("Marker") } };
        let marker_color = if color.is_null() { "#00D2FF" } else { unsafe { CStr::from_ptr(color).to_str().unwrap_or("#00D2FF") } };
        let marker_comment = if comment.is_null() { "" } else { unsafe { CStr::from_ptr(comment).to_str().unwrap_or("") } };

        match Project::from_json(json_str) {
            Ok(mut proj) => {
                let m = Marker {
                    id: uuid::Uuid::new_v4().to_string(),
                    time: RationalTime::from_f64(time_s),
                    name: marker_name.to_string(),
                    color: marker_color.to_string(),
                    comment: marker_comment.to_string(),
                };
                proj.timeline.add_marker(m);
                proj.to_json().unwrap_or_else(|_| "{}".into())
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_timeline_add_marker"),
    }
}

// -------------------- Subtitles --------------------

#[no_mangle]
pub extern "C" fn uvs_subtitles_parse(
    content: *const c_char,
    format_type: *const c_char,
    language: *const c_char,
    title: *const c_char,
) -> *mut c_char {
    if content.is_null() {
        return err_json("Null content in uvs_subtitles_parse");
    }

    let res = catch_unwind(|| {
        let c_str = unsafe { CStr::from_ptr(content).to_str().unwrap_or("") };
        let fmt = if format_type.is_null() { "srt" } else { unsafe { CStr::from_ptr(format_type).to_str().unwrap_or("srt") } };
        let lang = if language.is_null() { "en" } else { unsafe { CStr::from_ptr(language).to_str().unwrap_or("en") } };
        let t = if title.is_null() { "Subtitles" } else { unsafe { CStr::from_ptr(title).to_str().unwrap_or("Subtitles") } };

        let track_res = match fmt.to_lowercase().as_str() {
            "vtt" | "webvtt" => SubtitleTrack::parse_vtt(c_str, lang, t),
            "ass" | "ssa" => SubtitleTrack::parse_ass(c_str, lang, t),
            _ => SubtitleTrack::parse_srt(c_str, lang, t),
        };

        match track_res {
            Ok(track) => serde_json::to_string(&track).unwrap_or_else(|_| "{}".into()),
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_subtitles_parse"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_subtitles_export(track_json: *const c_char, format_type: *const c_char) -> *mut c_char {
    if track_json.is_null() {
        return err_json("Null track_json in uvs_subtitles_export");
    }

    let res = catch_unwind(|| {
        let j_str = unsafe { CStr::from_ptr(track_json).to_str().unwrap_or("") };
        let fmt = if format_type.is_null() { "srt" } else { unsafe { CStr::from_ptr(format_type).to_str().unwrap_or("srt") } };

        match serde_json::from_str::<SubtitleTrack>(j_str) {
            Ok(track) => match fmt.to_lowercase().as_str() {
                "vtt" | "webvtt" => track.to_vtt(),
                "ass" | "ssa" => track.to_ass(),
                _ => track.to_srt(),
            },
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_subtitles_export"),
    }
}

// -------------------- Audio DSP & Loudness --------------------

#[no_mangle]
pub extern "C" fn uvs_calculate_integrated_lufs(
    samples: *const f32,
    sample_count: usize,
    channels: usize,
    sample_rate: u32,
) -> f64 {
    if samples.is_null() || sample_count == 0 || channels == 0 {
        return -70.0;
    }

    let res = catch_unwind(|| {
        let slice = unsafe { std::slice::from_raw_parts(samples, sample_count) };
        let mut buf = AudioBuffer::new(channels, sample_rate, sample_count / channels);
        for (i, &s) in slice.iter().enumerate() {
            let ch = i % channels;
            let fr = i / channels;
            if fr < buf.samples[ch].len() {
                buf.samples[ch][fr] = s;
            }
        }
        calculate_integrated_lufs(&buf) as f64
    });

    res.unwrap_or(-70.0)
}

#[no_mangle]
pub extern "C" fn uvs_waveform_summary(sample_count: usize, target_points: usize) -> *mut c_char {
    let buf = AudioBuffer::new(2, 48000, sample_count);
    let summary = extract_waveform(&buf, target_points);
    let json = serde_json::to_string(&summary).unwrap_or_else(|_| "{}".into());
    to_c_string(json)
}

// -------------------- Color & Effects --------------------

#[no_mangle]
pub extern "C" fn uvs_apply_color_grading(
    rgba_ptr: *mut u8,
    width: c_uint,
    height: c_uint,
    config_json: *const c_char,
) -> c_int {
    if rgba_ptr.is_null() || width == 0 || height == 0 {
        return -1;
    }

    let res = catch_unwind(|| {
        let total_pixels = (width as usize) * (height as usize);
        let slice = unsafe { std::slice::from_raw_parts_mut(rgba_ptr, total_pixels * 4) };

        let cfg: ColorGradingConfig = if !config_json.is_null() {
            let s = unsafe { CStr::from_ptr(config_json).to_str().unwrap_or("{}") };
            serde_json::from_str(s).unwrap_or_default()
        } else {
            ColorGradingConfig::default()
        };

        for chunk in slice.chunks_exact_mut(4) {
            let r_f = chunk[0] as f64 / 255.0;
            let g_f = chunk[1] as f64 / 255.0;
            let b_f = chunk[2] as f64 / 255.0;
            let (r, g, b) = cfg.apply_to_rgb(r_f, g_f, b_f);
            chunk[0] = (r * 255.0).clamp(0.0, 255.0) as u8;
            chunk[1] = (g * 255.0).clamp(0.0, 255.0) as u8;
            chunk[2] = (b * 255.0).clamp(0.0, 255.0) as u8;
        }
        0
    });

    res.unwrap_or(-2)
}

#[no_mangle]
pub extern "C" fn uvs_apply_chroma_key(
    rgba_ptr: *mut u8,
    width: c_uint,
    height: c_uint,
    key_r: f64,
    key_g: f64,
    key_b: f64,
    tolerance: f64,
    softness: f64,
) -> c_int {
    if rgba_ptr.is_null() || width == 0 || height == 0 {
        return -1;
    }

    let res = catch_unwind(|| {
        let total_pixels = (width as usize) * (height as usize);
        let slice = unsafe { std::slice::from_raw_parts_mut(rgba_ptr, total_pixels * 4) };

        let cfg = ChromaKeyConfig {
            key_color_r: (key_r * 255.0).clamp(0.0, 255.0) as u8,
            key_color_g: (key_g * 255.0).clamp(0.0, 255.0) as u8,
            key_color_b: (key_b * 255.0).clamp(0.0, 255.0) as u8,
            similarity: tolerance,
            smoothness: softness,
            spill_suppression: 0.5,
        };

        for chunk in slice.chunks_exact_mut(4) {
            let (r, g, b, a) = cfg.process_pixel(chunk[0], chunk[1], chunk[2], chunk[3]);
            chunk[0] = r;
            chunk[1] = g;
            chunk[2] = b;
            chunk[3] = a;
        }
        0
    });

    res.unwrap_or(-2)
}

// -------------------- Automation & Multicam --------------------

#[no_mangle]
pub extern "C" fn uvs_detect_silence_segments(
    samples: *const f32,
    sample_count: usize,
    sample_rate: u32,
    threshold_db: f64,
    min_silence_s: f64,
) -> *mut c_char {
    if samples.is_null() || sample_count == 0 {
        return to_c_string("[]");
    }

    let res = catch_unwind(|| {
        let slice = unsafe { std::slice::from_raw_parts(samples, sample_count) };
        let intervals = detect_silence(slice, sample_rate, threshold_db as f32, min_silence_s);
        serde_json::to_string(&intervals).unwrap_or_else(|_| "[]".into())
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_detect_silence_segments"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_find_multicam_lag(
    samples_a: *const f32,
    len_a: usize,
    samples_b: *const f32,
    len_b: usize,
    max_lag: usize,
) -> i64 {
    if samples_a.is_null() || samples_b.is_null() || len_a == 0 || len_b == 0 {
        return 0;
    }

    let res = catch_unwind(|| {
        let a = unsafe { std::slice::from_raw_parts(samples_a, len_a) };
        let b = unsafe { std::slice::from_raw_parts(samples_b, len_b) };
        let (lag, _score) = find_audio_sync_lag(a, b, max_lag);
        lag
    });

    res.unwrap_or(0)
}

#[no_mangle]
pub extern "C" fn uvs_multicam_commit_cuts(
    project_json: *const c_char,
    group_json: *const c_char,
    cuts_json: *const c_char,
) -> *mut c_char {
    if project_json.is_null() || group_json.is_null() || cuts_json.is_null() {
        return err_json("Null argument to uvs_multicam_commit_cuts");
    }

    let res = catch_unwind(|| {
        let p_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let g_str = unsafe { CStr::from_ptr(group_json).to_str().unwrap_or("") };
        let c_str = unsafe { CStr::from_ptr(cuts_json).to_str().unwrap_or("") };

        let mut proj = match Project::from_json(p_str) {
            Ok(p) => p,
            Err(e) => return format!("{{\"error\": \"{}\"}}", e),
        };

        let group: crate::multicam::MulticamGroup = match serde_json::from_str(g_str) {
            Ok(g) => g,
            Err(e) => return format!("{{\"error\": \"Failed to parse group: {}\"}}", e),
        };

        #[derive(serde::Deserialize)]
        struct CutEventPayload {
            time_s: f64,
            angle_id: String,
        }
        let payloads: Vec<CutEventPayload> = match serde_json::from_str(c_str) {
            Ok(p) => p,
            Err(e) => return format!("{{\"error\": \"Failed to parse cuts: {}\"}}", e),
        };

        let cuts: Vec<(RationalTime, String)> = payloads
            .into_iter()
            .map(|p| (RationalTime::from_f64(p.time_s), p.angle_id))
            .collect();

        match group.commit_angle_cuts_to_timeline(&cuts, &mut proj.timeline) {
            Ok(count) => {
                let new_json = proj.to_json().unwrap_or_else(|_| "{}".into());
                format!("{{\"inserted_cuts\": {}, \"project\": {}}}", count, new_json)
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_multicam_commit_cuts"),
    }
}

// -------------------- Render Execution --------------------

#[no_mangle]
pub extern "C" fn uvs_build_render_command(
    project_json: *const c_char,
    input_path: *const c_char,
    output_path: *const c_char,
) -> *mut c_char {
    if project_json.is_null() || input_path.is_null() || output_path.is_null() {
        return err_json("Null argument to uvs_build_render_command");
    }

    let res = catch_unwind(|| {
        let j_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let in_p = unsafe { CStr::from_ptr(input_path).to_str().unwrap_or("") };
        let out_p = unsafe { CStr::from_ptr(output_path).to_str().unwrap_or("") };

        match Project::from_json(j_str) {
            Ok(proj) => {
                let caps = HardwareCapabilities::detect();
                let args = build_ffmpeg_render_args(in_p, out_p, &proj.render_settings, &caps);
                serde_json::to_string(&args).unwrap_or_else(|_| "[]".into())
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_build_render_command"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_execute_render(
    project_json: *const c_char,
    input_path: *const c_char,
    output_path: *const c_char,
) -> *mut c_char {
    if project_json.is_null() || input_path.is_null() || output_path.is_null() {
        return err_json("Null argument to uvs_execute_render");
    }

    let res = catch_unwind(|| {
        let j_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
        let in_p = unsafe { CStr::from_ptr(input_path).to_str().unwrap_or("") };
        let out_p = unsafe { CStr::from_ptr(output_path).to_str().unwrap_or("") };

        match Project::from_json(j_str) {
            Ok(proj) => {
                let caps = HardwareCapabilities::detect();
                match execute_ffmpeg_render(in_p, out_p, &proj.render_settings, &caps) {
                    Ok(msg) => format!("{{\"status\": \"ok\", \"message\": \"{}\"}}", msg),
                    Err(e) => format!("{{\"status\": \"failed\", \"error\": \"{}\"}}", e),
                }
            }
            Err(e) => format!("{{\"error\": \"{}\"}}", e),
        }
    });

    match res {
        Ok(s) => to_c_string(s),
        Err(_) => err_json("Panic in uvs_execute_render"),
    }
}

#[no_mangle]
pub extern "C" fn uvs_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}
