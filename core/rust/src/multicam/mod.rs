use crate::timeline::RationalTime;
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

        if count > 10 && norm_ref > 1e-6 && norm_target > 1e-6 {
            let corr = dot / (norm_ref.sqrt() * norm_target.sqrt());
            if corr > best_corr {
                best_corr = corr;
                best_lag = lag;
            }
        }
    }

    (best_lag, best_corr.max(0.0))
}
