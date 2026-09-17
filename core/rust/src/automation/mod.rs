use crate::timeline::RationalTime;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TimeInterval {
    pub start: RationalTime,
    pub end: RationalTime,
}

impl TimeInterval {
    pub fn duration(&self) -> RationalTime {
        self.end - self.start
    }
}

/// Detects silence intervals in an audio track
pub fn detect_silence(
    samples: &[f32],
    sample_rate: u32,
    threshold_db: f32, // e.g. -40.0 dB
    min_silence_duration_seconds: f64,
) -> Vec<TimeInterval> {
    let mut intervals = Vec::new();
    if samples.is_empty() || sample_rate == 0 {
        return intervals;
    }

    let threshold_linear = 10.0f32.powf(threshold_db / 20.0);
    let min_samples = (min_silence_duration_seconds * sample_rate as f64) as usize;

    let window_size = (sample_rate / 50).max(1) as usize; // 20ms windows
    let mut in_silence = false;
    let mut silence_start_sample = 0usize;

    for (w_idx, chunk) in samples.chunks(window_size).enumerate() {
        let mut sum_sq = 0.0f32;
        for s in chunk {
            sum_sq += s * s;
        }
        let rms = (sum_sq / chunk.len() as f32).sqrt();

        if rms < threshold_linear {
            if !in_silence {
                in_silence = true;
                silence_start_sample = w_idx * window_size;
            }
        } else if in_silence {
            let silence_end_sample = w_idx * window_size;
            if silence_end_sample - silence_start_sample >= min_samples {
                intervals.push(TimeInterval {
                    start: RationalTime::from_f64(silence_start_sample as f64 / sample_rate as f64),
                    end: RationalTime::from_f64(silence_end_sample as f64 / sample_rate as f64),
                });
            }
            in_silence = false;
        }
    }

    if in_silence {
        let silence_end_sample = samples.len();
        if silence_end_sample - silence_start_sample >= min_samples {
            intervals.push(TimeInterval {
                start: RationalTime::from_f64(silence_start_sample as f64 / sample_rate as f64),
                end: RationalTime::from_f64(silence_end_sample as f64 / sample_rate as f64),
            });
        }
    }

    intervals
}

/// Detects scene cut frame indices using histogram difference threshold
pub fn detect_scene_cuts(histograms: &[Vec<f32>], threshold: f32) -> Vec<usize> {
    let mut cuts = Vec::new();
    if histograms.len() < 2 {
        return cuts;
    }

    for (i, pair) in histograms.windows(2).enumerate() {
        let (h1, h2) = (&pair[0], &pair[1]);
        let mut diff = 0.0f32;
        let len = h1.len().min(h2.len());
        for k in 0..len {
            diff += (h1[k] - h2[k]).abs();
        }
        if diff > threshold {
            cuts.push(i + 1); // Frame index where cut occurred
        }
    }

    cuts
}

/// Computes smart reframing bounding box for target aspect ratio given subject center
pub fn calculate_reframe_crop(
    src_width: u32,
    src_height: u32,
    target_aspect: f64,    // e.g. 9.0 / 16.0 = 0.5625
    subject_center_x: f64, // 0.0 to 1.0
) -> (f64, f64, f64, f64) {
    // Returns (crop_left, crop_right, crop_top, crop_bottom) normalized 0.0 to 1.0
    let src_aspect = src_width as f64 / src_height as f64;

    if target_aspect < src_aspect {
        // Target is narrower (e.g. 16:9 -> 9:16)
        let new_crop_width = src_height as f64 * target_aspect;
        let width_fraction = (new_crop_width / src_width as f64).clamp(0.0, 1.0);

        let half_w = width_fraction * 0.5;
        let center = subject_center_x.clamp(half_w, 1.0 - half_w);

        let crop_left = center - half_w;
        let crop_right = 1.0 - (center + half_w);
        (crop_left, crop_right, 0.0, 0.0)
    } else {
        // Target is wider
        let new_crop_height = src_width as f64 / target_aspect;
        let height_fraction = (new_crop_height / src_height as f64).clamp(0.0, 1.0);
        let crop_top = (1.0 - height_fraction) * 0.5;
        let crop_bottom = crop_top;
        (0.0, 0.0, crop_top, crop_bottom)
    }
}
