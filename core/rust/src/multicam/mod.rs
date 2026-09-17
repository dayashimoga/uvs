use crate::timeline::{Clip, RationalTime, Timeline, Track, TrackType};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SyncMethod {
    Timecode,
    FileCreationTimestamp,
    AudioWaveformCorrelation,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MulticamAngle {
    pub id: String,
    pub name: String,
    pub media_path: String,
    pub sync_offset: RationalTime,
    pub is_active: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MulticamGroup {
    pub id: String,
    pub name: String,
    pub sync_method: SyncMethod,
    pub angles: Vec<MulticamAngle>,
}

impl MulticamGroup {
    pub fn new(id: impl Into<String>, name: impl Into<String>, sync_method: SyncMethod) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            sync_method,
            angles: Vec::new(),
        }
    }

    pub fn add_angle(&mut self, angle: MulticamAngle) {
        self.angles.push(angle);
    }

    pub fn set_active_angle(&mut self, angle_id: &str) {
        for angle in &mut self.angles {
            angle.is_active = angle.id == angle_id;
        }
    }

    pub fn active_angle(&self) -> Option<&MulticamAngle> {
        self.angles.iter().find(|a| a.is_active)
    }

    /// Commits a sequence of multicam angle cuts to the provided timeline.
    /// `cut_events` contains `(timeline_playhead, angle_id)`.
    /// Generates synchronized video clips on the primary video track and
    /// linked audio clips on the primary audio track.
    pub fn commit_angle_cuts_to_timeline(
        &self,
        cut_events: &[(RationalTime, String)],
        timeline: &mut Timeline,
    ) -> Result<usize, String> {
        if cut_events.is_empty() {
            return Err("No cut events provided".into());
        }
        if self.angles.is_empty() {
            return Err("Multicam group has no angles".into());
        }

        // Find or create primary video track
        let v_track_id = match timeline
            .tracks
            .iter()
            .find(|t| t.track_type == TrackType::Video)
        {
            Some(t) => t.id.clone(),
            None => {
                let t = Track::new("V1", TrackType::Video, 0);
                let tid = t.id.clone();
                timeline.add_track(t);
                tid
            }
        };

        // Find or create primary audio track
        let a_track_id = match timeline
            .tracks
            .iter()
            .find(|t| t.track_type == TrackType::Audio)
        {
            Some(t) => t.id.clone(),
            None => {
                let t = Track::new("A1", TrackType::Audio, 0);
                let tid = t.id.clone();
                timeline.add_track(t);
                tid
            }
        };

        let mut cuts_sorted = cut_events.to_vec();
        cuts_sorted.sort_by_key(|a| a.0);

        let mut inserted_count = 0;

        for i in 0..cuts_sorted.len() {
            let start = cuts_sorted[i].0;
            let angle_id = &cuts_sorted[i].1;

            // Determine duration to next cut, or default 5s if last cut
            let duration = if i + 1 < cuts_sorted.len() {
                cuts_sorted[i + 1].0 - start
            } else {
                RationalTime::from_f64(5.0)
            };

            if duration.as_f64() <= 0.0 {
                continue;
            }

            let angle = match self.angles.iter().find(|a| &a.id == angle_id) {
                Some(a) => a,
                None => continue,
            };

            // Source in-point = timeline start + sync_offset
            let source_in = start + angle.sync_offset;
            let source_out = source_in + duration;

            let mut v_clip = Clip::new(
                format!("{} (Cut {})", angle.name, i + 1),
                &angle.media_path,
                start,
                duration,
            );
            v_clip.in_point = source_in;
            v_clip.out_point = source_out;

            let mut a_clip = Clip::new(
                format!("{} Audio", angle.name),
                &angle.media_path,
                start,
                duration,
            );
            a_clip.in_point = source_in;
            a_clip.out_point = source_out;

            let v_clip_id = v_clip.id.clone();
            let a_clip_id = a_clip.id.clone();

            v_clip.linked_clip_id = Some(a_clip_id.clone());
            a_clip.linked_clip_id = Some(v_clip_id.clone());

            if let Some(vt) = timeline.tracks.iter_mut().find(|t| t.id == v_track_id) {
                let _ = vt.add_clip(v_clip);
            }
            if let Some(at) = timeline.tracks.iter_mut().find(|t| t.id == a_track_id) {
                let _ = at.add_clip(a_clip);
            }

            inserted_count += 1;
        }

        Ok(inserted_count)
    }
}

/// Computes normalized cross-correlation between two audio peak/energy vectors
/// to find best alignment lag in samples.
pub fn find_audio_sync_lag(sig_ref: &[f32], sig_target: &[f32], max_lag: usize) -> (i64, f32) {
    if sig_ref.is_empty() || sig_target.is_empty() {
        return (0, 0.0);
    }

    let mut best_lag = 0i64;
    let mut best_corr = -1.0f32;

    let search_range = max_lag.min(sig_ref.len()).min(sig_target.len());

    for lag in -(search_range as i64)..=(search_range as i64) {
        let mut dot = 0.0f32;
        let mut norm_ref = 0.0f32;
        let mut norm_target = 0.0f32;
        let mut count = 0;

        for (i, &val_ref) in sig_ref.iter().enumerate() {
            let target_idx = i as i64 + lag;
            if target_idx >= 0 && (target_idx as usize) < sig_target.len() {
                let val_tgt = sig_target[target_idx as usize];
                dot += val_ref * val_tgt;
                norm_ref += val_ref * val_ref;
                norm_target += val_tgt * val_tgt;
                count += 1;
            }
        }

        if count >= 4 && norm_ref > 1e-6 && norm_target > 1e-6 {
            let corr = dot / (norm_ref.sqrt() * norm_target.sqrt());
            if corr > best_corr {
                best_corr = corr;
                best_lag = lag;
            }
        }
    }

    (best_lag, best_corr.max(0.0))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::timeline::TimecodeConfig;

    #[test]
    fn test_find_audio_sync_lag() {
        // Synthesize reference signal
        let sig_ref = vec![0.1, 0.5, 0.9, 0.4, 0.2, 0.0, 0.0, 0.0];
        // Target is shifted by +2 samples
        let sig_target = vec![0.0, 0.0, 0.1, 0.5, 0.9, 0.4, 0.2, 0.0];

        let (lag, corr) = find_audio_sync_lag(&sig_ref, &sig_target, 4);
        assert_eq!(lag, 2);
        assert!(
            corr > 0.95,
            "Correlation should be close to 1.0, got {}",
            corr
        );
    }

    #[test]
    fn test_multicam_commit_cuts() {
        let mut group = MulticamGroup::new("g1", "QuadCam", SyncMethod::AudioWaveformCorrelation);
        group.add_angle(MulticamAngle {
            id: "cam1".into(),
            name: "Cam 1 Wide".into(),
            media_path: "cam1.mp4".into(),
            sync_offset: RationalTime::from_f64(0.0),
            is_active: true,
        });
        group.add_angle(MulticamAngle {
            id: "cam2".into(),
            name: "Cam 2 Close".into(),
            media_path: "cam2.mp4".into(),
            sync_offset: RationalTime::from_f64(1.5),
            is_active: false,
        });

        let mut timeline = Timeline::new(1920, 1080, TimecodeConfig::default());
        let cuts = vec![
            (RationalTime::from_f64(0.0), "cam1".into()),
            (RationalTime::from_f64(4.0), "cam2".into()),
            (RationalTime::from_f64(10.0), "cam1".into()),
        ];

        let inserted = group
            .commit_angle_cuts_to_timeline(&cuts, &mut timeline)
            .unwrap();
        assert_eq!(inserted, 3);

        let v_track = timeline
            .tracks
            .iter()
            .find(|t| t.track_type == TrackType::Video)
            .unwrap();
        assert_eq!(v_track.clips.len(), 3);
        assert_eq!(v_track.clips[0].name, "Cam 1 Wide (Cut 1)");
        assert_eq!(v_track.clips[1].name, "Cam 2 Close (Cut 2)");
        // Check in_point offset for cam2 includes sync_offset (4.0 + 1.5 = 5.5)
        assert_eq!(v_track.clips[1].in_point, RationalTime::from_f64(5.5));
    }
}
