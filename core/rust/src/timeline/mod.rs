pub mod timecode;

use serde::{Deserialize, Serialize};
pub use timecode::{RationalTime, TimecodeConfig};
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum TrackType {
    Video,
    Audio,
    Subtitle,
    Adjustment,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum BlendMode {
    Normal,
    Add,
    Multiply,
    Screen,
    Overlay,
}

impl Default for BlendMode {
    fn default() -> Self {
        BlendMode::Normal
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Transform {
    pub position_x: f64,
    pub position_y: f64,
    pub scale_x: f64,
    pub scale_y: f64,
    pub rotation: f64, // in degrees
    pub anchor_x: f64,
    pub anchor_y: f64,
    pub crop_left: f64,
    pub crop_right: f64,
    pub crop_top: f64,
    pub crop_bottom: f64,
}

impl Default for Transform {
    fn default() -> Self {
        Self {
            position_x: 0.0,
            position_y: 0.0,
            scale_x: 1.0,
            scale_y: 1.0,
            rotation: 0.0,
            anchor_x: 0.5,
            anchor_y: 0.5,
            crop_left: 0.0,
            crop_right: 0.0,
            crop_top: 0.0,
            crop_bottom: 0.0,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Interpolation {
    Linear,
    EaseIn,
    EaseOut,
    Bezier,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Keyframe {
    pub time: RationalTime,
    pub value: f64,
    pub interpolation: Interpolation,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct KeyframeTrack {
    pub property_name: String,
    pub keyframes: Vec<Keyframe>,
}

impl KeyframeTrack {
    pub fn new(property_name: impl Into<String>) -> Self {
        Self {
            property_name: property_name.into(),
            keyframes: Vec::new(),
        }
    }

    pub fn add_keyframe(&mut self, kf: Keyframe) {
        self.keyframes.push(kf);
        self.keyframes.sort_by(|a, b| a.time.cmp(&b.time));
    }

    pub fn value_at(&self, time: RationalTime, default_val: f64) -> f64 {
        if self.keyframes.is_empty() {
            return default_val;
        }
        if time <= self.keyframes[0].time {
            return self.keyframes[0].value;
        }
        if time >= self.keyframes.last().unwrap().time {
            return self.keyframes.last().unwrap().value;
        }

        // Find surrounding keyframes
        for window in self.keyframes.windows(2) {
            let (k1, k2) = (&window[0], &window[1]);
            if time >= k1.time && time <= k2.time {
                let dt = (k2.time - k1.time).as_f64();
                if dt.abs() < 1e-6 {
                    return k1.value;
                }
                let t = ((time - k1.time).as_f64() / dt).clamp(0.0, 1.0);
                return match k1.interpolation {
                    Interpolation::Linear => k1.value + (k2.value - k1.value) * t,
                    Interpolation::EaseIn => k1.value + (k2.value - k1.value) * (t * t),
                    Interpolation::EaseOut => k1.value + (k2.value - k1.value) * (t * (2.0 - t)),
                    Interpolation::Bezier => {
                        let t_smooth = t * t * (3.0 - 2.0 * t);
                        k1.value + (k2.value - k1.value) * t_smooth
                    }
                };
            }
        }
        default_val
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TransitionType {
    CrossDissolve,
    FadeColor,
    WipeLeft,
    WipeRight,
    Slide,
    Zoom,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Transition {
    pub id: String,
    pub transition_type: TransitionType,
    pub duration: RationalTime,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Marker {
    pub id: String,
    pub time: RationalTime,
    pub name: String,
    pub color: String,
    pub comment: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Clip {
    pub id: String,
    pub name: String,
    pub media_path: String,
    pub in_point: RationalTime,
    pub out_point: RationalTime,
    pub start_time: RationalTime,
    pub duration: RationalTime,
    pub speed: f64,
    pub volume: f64,
    pub opacity: f64,
    pub blend_mode: BlendMode,
    pub transform: Transform,
    pub keyframe_tracks: Vec<KeyframeTrack>,
    pub transition_in: Option<Transition>,
    pub transition_out: Option<Transition>,
}

impl Clip {
    pub fn new(
        name: impl Into<String>,
        media_path: impl Into<String>,
        start_time: RationalTime,
        duration: RationalTime,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name: name.into(),
            media_path: media_path.into(),
            in_point: RationalTime::zero(),
            out_point: duration,
            start_time,
            duration,
            speed: 1.0,
            volume: 1.0,
            opacity: 1.0,
            blend_mode: BlendMode::Normal,
            transform: Transform::default(),
            keyframe_tracks: Vec::new(),
            transition_in: None,
            transition_out: None,
        }
    }

    pub fn end_time(&self) -> RationalTime {
        self.start_time + self.duration
    }

    pub fn contains_time(&self, time: RationalTime) -> bool {
        time >= self.start_time && time < self.end_time()
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Track {
    pub id: String,
    pub name: String,
    pub track_type: TrackType,
    pub z_index: i32,
    pub muted: bool,
    pub solo: bool,
    pub locked: bool,
    pub opacity: f64,
    pub volume: f64,
    pub pan: f64,
    pub clips: Vec<Clip>,
}

impl Track {
    pub fn new(name: impl Into<String>, track_type: TrackType, z_index: i32) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name: name.into(),
            track_type,
            z_index,
            muted: false,
            solo: false,
            locked: false,
            opacity: 1.0,
            volume: 1.0,
            pan: 0.0,
            clips: Vec::new(),
        }
    }

    pub fn add_clip(&mut self, clip: Clip) -> Result<(), String> {
        // Validate overlap
        for existing in &self.clips {
            let overlaps = !(clip.end_time() <= existing.start_time || clip.start_time >= existing.end_time());
            if overlaps {
                return Err(format!(
                    "Clip '{}' [{}-{}] overlaps with existing clip '{}' [{}-{}]",
                    clip.name, clip.start_time, clip.end_time(), existing.name, existing.start_time, existing.end_time()
                ));
            }
        }
        self.clips.push(clip);
        self.clips.sort_by(|a, b| a.start_time.cmp(&b.start_time));
        Ok(())
    }

    pub fn clip_at(&self, time: RationalTime) -> Option<&Clip> {
        self.clips.iter().find(|c| c.contains_time(time))
    }

    pub fn clip_at_mut(&mut self, time: RationalTime) -> Option<&mut Clip> {
        self.clips.iter_mut().find(|c| c.contains_time(time))
    }

    pub fn duration(&self) -> RationalTime {
        self.clips
            .iter()
            .map(|c| c.end_time())
            .max()
            .unwrap_or_else(RationalTime::zero)
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Timeline {
    pub timecode_config: TimecodeConfig,
    pub canvas_width: u32,
    pub canvas_height: u32,
    pub tracks: Vec<Track>,
    pub markers: Vec<Marker>,
}

impl Timeline {
    pub fn new(width: u32, height: u32, timecode_config: TimecodeConfig) -> Self {
        Self {
            timecode_config,
            canvas_width: width,
            canvas_height: height,
            tracks: Vec::new(),
            markers: Vec::new(),
        }
    }

    pub fn add_track(&mut self, track: Track) {
        self.tracks.push(track);
        self.tracks.sort_by_key(|t| t.z_index);
    }

    pub fn total_duration(&self) -> RationalTime {
        self.tracks
            .iter()
            .map(|t| t.duration())
            .max()
            .unwrap_or_else(RationalTime::zero)
    }

    pub fn active_clips_at(&self, time: RationalTime) -> Vec<(&Track, &Clip)> {
        let has_solo = self.tracks.iter().any(|t| t.solo);
        let mut active = Vec::new();
        for track in &self.tracks {
            if track.muted {
                continue;
            }
            if has_solo && !track.solo {
                continue;
            }
            if let Some(clip) = track.clip_at(time) {
                active.push((track, clip));
            }
        }
        active
    }

    pub fn split_clip_at(&mut self, track_id: &str, clip_id: &str, split_time: RationalTime) -> Result<(), String> {
        let track = self.tracks.iter_mut().find(|t| t.id == track_id)
            .ok_or_else(|| format!("Track not found: {}", track_id))?;
        
        let clip_idx = track.clips.iter().position(|c| c.id == clip_id)
            .ok_or_else(|| format!("Clip not found: {}", clip_id))?;
        
        let clip = &track.clips[clip_idx];
        if split_time <= clip.start_time || split_time >= clip.end_time() {
            return Err(format!("Split time {} is outside clip range [{}, {}]", split_time, clip.start_time, clip.end_time()));
        }

        let first_dur = split_time - clip.start_time;
        let second_dur = clip.duration - first_dur;

        let mut first_clip = clip.clone();
        first_clip.duration = first_dur;
        first_clip.out_point = first_clip.in_point + first_dur;

        let mut second_clip = clip.clone();
        second_clip.id = Uuid::new_v4().to_string();
        second_clip.start_time = split_time;
        second_clip.duration = second_dur;
        second_clip.in_point = first_clip.out_point;

        track.clips[clip_idx] = first_clip;
        track.clips.insert(clip_idx + 1, second_clip);
        track.clips.sort_by(|a, b| a.start_time.cmp(&b.start_time));
        Ok(())
    }

    pub fn ripple_delete(&mut self, track_id: &str, clip_id: &str) -> Result<(), String> {
        let track = self.tracks.iter_mut().find(|t| t.id == track_id)
            .ok_or_else(|| format!("Track not found: {}", track_id))?;
        
        let clip_idx = track.clips.iter().position(|c| c.id == clip_id)
            .ok_or_else(|| format!("Clip not found: {}", clip_id))?;
        
        let removed_clip = track.clips.remove(clip_idx);
        let shift_amount = removed_clip.duration;

        // Shift subsequent clips to the left
        for clip in &mut track.clips[clip_idx..] {
            clip.start_time = clip.start_time - shift_amount;
        }
        Ok(())
    }
}
