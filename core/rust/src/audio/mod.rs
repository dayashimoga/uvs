use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq)]
pub struct AudioBuffer {
    pub channels: usize,
    pub sample_rate: u32,
    pub samples: Vec<Vec<f32>>, // [channel][sample_index]
}

impl AudioBuffer {
    pub fn new(channels: usize, sample_rate: u32, frames: usize) -> Self {
        Self {
            channels,
            sample_rate,
            samples: vec![vec![0.0f32; frames]; channels],
        }
    }

    pub fn frames(&self) -> usize {
        if self.samples.is_empty() { 0 } else { self.samples[0].len() }
    }

    pub fn apply_gain(&mut self, gain_linear: f32) {
        for ch in &mut self.samples {
            for sample in ch {
                *sample *= gain_linear;
            }
        }
    }

    pub fn apply_pan(&mut self, pan: f32) {
        // Pan from -1.0 (Left) to +1.0 (Right) using constant power pan law
        if self.channels != 2 {
            return;
        }
        let pan_norm = (pan.clamp(-1.0, 1.0) + 1.0) * 0.5; // 0.0 (L) to 1.0 (R)
        let angle = pan_norm * std::f32::consts::FRAC_PI_2;
        let gain_l = angle.cos();
        let gain_r = angle.sin();

        for s in &mut self.samples[0] {
            *s *= gain_l;
        }
        for s in &mut self.samples[1] {
            *s *= gain_r;
        }
    }
}

/// Biquad filter implementation (Robert Bristow-Johnson Audio EQ Cookbook)
#[derive(Debug, Clone)]
pub struct BiquadFilter {
    b0: f32, b1: f32, b2: f32,
    a1: f32, a2: f32,
    x1: f32, x2: f32,
    y1: f32, y2: f32,
}

impl BiquadFilter {
    pub fn new_peaking(sample_rate: f32, freq: f32, q: f32, gain_db: f32) -> Self {
        let a = 10.0f32.powf(gain_db / 40.0);
        let omega = 2.0 * std::f32::consts::PI * freq / sample_rate;
        let alpha = omega.sin() / (2.0 * q);
        let cos_w = omega.cos();

        let b0 = 1.0 + alpha * a;
        let b1 = -2.0 * cos_w;
        let b2 = 1.0 - alpha * a;
        let a0 = 1.0 + alpha / a;
        let a1 = -2.0 * cos_w;
        let a2 = 1.0 - alpha / a;

        Self {
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0,
            x1: 0.0, x2: 0.0,
            y1: 0.0, y2: 0.0,
        }
    }

    pub fn new_low_shelf(sample_rate: f32, freq: f32, gain_db: f32) -> Self {
        let a = 10.0f32.powf(gain_db / 40.0);
        let omega = 2.0 * std::f32::consts::PI * freq / sample_rate;
        let cos_w = omega.cos();
        let sin_w = omega.sin();
        let alpha = sin_w / (2.0 * std::f32::consts::SQRT_2);

        let b0 = a * ((a + 1.0) - (a - 1.0) * cos_w + 2.0 * a.sqrt() * alpha);
        let b1 = 2.0 * a * ((a - 1.0) - (a + 1.0) * cos_w);
        let b2 = a * ((a + 1.0) - (a - 1.0) * cos_w - 2.0 * a.sqrt() * alpha);
        let a0 = (a + 1.0) + (a - 1.0) * cos_w + 2.0 * a.sqrt() * alpha;
        let a1 = -2.0 * ((a - 1.0) + (a + 1.0) * cos_w);
        let a2 = (a + 1.0) + (a - 1.0) * cos_w - 2.0 * a.sqrt() * alpha;

        Self {
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0,
            x1: 0.0, x2: 0.0,
            y1: 0.0, y2: 0.0,
        }
    }

    pub fn new_high_shelf(sample_rate: f32, freq: f32, gain_db: f32) -> Self {
        let a = 10.0f32.powf(gain_db / 40.0);
        let omega = 2.0 * std::f32::consts::PI * freq / sample_rate;
        let cos_w = omega.cos();
        let sin_w = omega.sin();
        let alpha = sin_w / (2.0 * std::f32::consts::SQRT_2);

        let b0 = a * ((a + 1.0) + (a - 1.0) * cos_w + 2.0 * a.sqrt() * alpha);
        let b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cos_w);
        let b2 = a * ((a + 1.0) + (a - 1.0) * cos_w - 2.0 * a.sqrt() * alpha);
        let a0 = (a + 1.0) - (a - 1.0) * cos_w + 2.0 * a.sqrt() * alpha;
        let a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cos_w);
        let a2 = (a + 1.0) - (a - 1.0) * cos_w - 2.0 * a.sqrt() * alpha;

        Self {
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0,
            x1: 0.0, x2: 0.0,
            y1: 0.0, y2: 0.0,
        }
    }

    pub fn process_sample(&mut self, x: f32) -> f32 {
        let y = self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2;
        self.x2 = self.x1;
        self.x1 = x;
        self.y2 = self.y1;
        self.y1 = y;
        y
    }
}

/// 5-band Parametric Equalizer configuration
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EqualizerConfig {
    pub low_shelf_gain: f32,   // 100 Hz
    pub low_mid_gain: f32,     // 500 Hz
    pub mid_gain: f32,         // 1.5 kHz
    pub high_mid_gain: f32,    // 4 kHz
    pub high_shelf_gain: f32,  // 10 kHz
}

impl Default for EqualizerConfig {
    fn default() -> Self {
        Self {
            low_shelf_gain: 0.0,
            low_mid_gain: 0.0,
            mid_gain: 0.0,
            high_mid_gain: 0.0,
            high_shelf_gain: 0.0,
        }
    }
}

pub struct Equalizer {
    filters: Vec<Vec<BiquadFilter>>, // [channel][band]
}

impl Equalizer {
    pub fn new(sample_rate: u32, channels: usize, config: &EqualizerConfig) -> Self {
        let sr = sample_rate as f32;
        let mut ch_filters = Vec::new();
        for _ in 0..channels {
            let bands = vec![
                BiquadFilter::new_low_shelf(sr, 100.0, config.low_shelf_gain),
                BiquadFilter::new_peaking(sr, 500.0, 1.0, config.low_mid_gain),
                BiquadFilter::new_peaking(sr, 1500.0, 1.0, config.mid_gain),
                BiquadFilter::new_peaking(sr, 4000.0, 1.0, config.high_mid_gain),
                BiquadFilter::new_high_shelf(sr, 10000.0, config.high_shelf_gain),
            ];
            ch_filters.push(bands);
        }
        Self { filters: ch_filters }
    }

    pub fn process(&mut self, buffer: &mut AudioBuffer) {
        for (ch_idx, ch) in buffer.samples.iter_mut().enumerate() {
            if ch_idx < self.filters.len() {
                let bands = &mut self.filters[ch_idx];
                for sample in ch.iter_mut() {
                    let mut s = *sample;
                    for band in bands.iter_mut() {
                        s = band.process_sample(s);
                    }
                    *sample = s;
                }
            }
        }
    }
}

/// Dynamic Audio Compressor / Limiter
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CompressorConfig {
    pub threshold_db: f32, // e.g. -20.0 dB
    pub ratio: f32,        // e.g. 4.0
    pub attack_ms: f32,    // e.g. 5.0 ms
    pub release_ms: f32,   // e.g. 100.0 ms
    pub makeup_gain_db: f32,
}

impl Default for CompressorConfig {
    fn default() -> Self {
        Self {
            threshold_db: -18.0,
            ratio: 3.0,
            attack_ms: 10.0,
            release_ms: 100.0,
            makeup_gain_db: 0.0,
        }
    }
}

pub struct Compressor {
    config: CompressorConfig,
    envelope: f32,
    attack_coeff: f32,
    release_coeff: f32,
}

impl Compressor {
    pub fn new(sample_rate: u32, config: CompressorConfig) -> Self {
        let sr = sample_rate as f32;
        let attack_coeff = (-1.0 / (config.attack_ms * 0.001 * sr)).exp();
        let release_coeff = (-1.0 / (config.release_ms * 0.001 * sr)).exp();
        Self {
            config,
            envelope: 0.0,
            attack_coeff,
            release_coeff,
        }
    }

    pub fn process(&mut self, buffer: &mut AudioBuffer) {
        let makeup_linear = 10.0f32.powf(self.config.makeup_gain_db / 20.0);
        let frames = buffer.frames();

        for f in 0..frames {
            // Find max absolute sample across channels for peak detection
            let mut peak = 0.0f32;
            for ch in 0..buffer.channels {
                let abs_s = buffer.samples[ch][f].abs();
                if abs_s > peak {
                    peak = abs_s;
                }
            }

            // Envelope follower
            if peak > self.envelope {
                self.envelope = self.attack_coeff * self.envelope + (1.0 - self.attack_coeff) * peak;
            } else {
                self.envelope = self.release_coeff * self.envelope + (1.0 - self.release_coeff) * peak;
            }

            // Compute gain reduction
            let env_db = 20.0 * (self.envelope.max(1e-6)).log10();
            let gain_reduction_db = if env_db > self.config.threshold_db {
                (self.config.threshold_db - env_db) * (1.0 - 1.0 / self.config.ratio)
            } else {
                0.0
            };

            let gain = 10.0f32.powf(gain_reduction_db / 20.0) * makeup_linear;

            for ch in 0..buffer.channels {
                buffer.samples[ch][f] *= gain;
            }
        }
    }
}

/// EBU R128 / ITU-R BS.1770 integrated loudness calculator (approximate LUFS)
pub fn calculate_integrated_lufs(buffer: &AudioBuffer) -> f32 {
    let frames = buffer.frames();
    if frames == 0 || buffer.channels == 0 {
        return -70.0; // Silence floor
    }

    let mut sum_sq = 0.0f64;
    let mut total_samples = 0usize;

    for ch in 0..buffer.channels {
        for s in &buffer.samples[ch] {
            sum_sq += (*s as f64) * (*s as f64);
            total_samples += 1;
        }
    }

    let mean_sq = sum_sq / (total_samples as f64).max(1.0);
    if mean_sq <= 1e-12 {
        return -70.0;
    }

    let lufs = -0.691 + 10.0 * mean_sq.log10();
    lufs as f32
}

/// Waveform peak and RMS sample summary for timeline visualization
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct WaveformSummary {
    pub peaks: Vec<f32>,
    pub rms: Vec<f32>,
    pub window_size: usize,
}

pub fn extract_waveform(buffer: &AudioBuffer, target_points: usize) -> WaveformSummary {
    let frames = buffer.frames();
    if frames == 0 || target_points == 0 {
        return WaveformSummary {
            peaks: Vec::new(),
            rms: Vec::new(),
            window_size: 1,
        };
    }

    let window_size = (frames / target_points).max(1);
    let mut peaks = Vec::with_capacity(target_points);
    let mut rms = Vec::with_capacity(target_points);

    for chunk_start in (0..frames).step_by(window_size) {
        let chunk_end = (chunk_start + window_size).min(frames);
        let mut max_val = 0.0f32;
        let mut sum_sq = 0.0f32;
        let count = chunk_end - chunk_start;

        for f in chunk_start..chunk_end {
            for ch in 0..buffer.channels {
                let val = buffer.samples[ch][f].abs();
                if val > max_val {
                    max_val = val;
                }
                sum_sq += val * val;
            }
        }

        let chunk_rms = (sum_sq / (count * buffer.channels) as f32).sqrt();
        peaks.push(max_val);
        rms.push(chunk_rms);
    }

    WaveformSummary {
        peaks,
        rms,
        window_size,
    }
}
