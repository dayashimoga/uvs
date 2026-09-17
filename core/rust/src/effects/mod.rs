use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ColorGradingConfig {
    pub exposure: f64,    // -5.0 to +5.0
    pub contrast: f64,    // 0.0 to 2.0, default 1.0
    pub highlights: f64,  // -1.0 to 1.0, default 0.0
    pub shadows: f64,     // -1.0 to 1.0, default 0.0
    pub whites: f64,      // -1.0 to 1.0, default 0.0
    pub blacks: f64,      // -1.0 to 1.0, default 0.0
    pub temperature: f64, // -100 to +100 (warm / cool)
    pub tint: f64,        // -100 to +100 (magenta / green)
    pub saturation: f64,  // 0.0 to 2.0, default 1.0
    pub vibrance: f64,    // -1.0 to 1.0, default 0.0
}

impl Default for ColorGradingConfig {
    fn default() -> Self {
        Self {
            exposure: 0.0,
            contrast: 1.0,
            highlights: 0.0,
            shadows: 0.0,
            whites: 0.0,
            blacks: 0.0,
            temperature: 0.0,
            tint: 0.0,
            saturation: 1.0,
            vibrance: 0.0,
        }
    }
}

impl ColorGradingConfig {
    pub fn apply_to_rgb(&self, r: f64, g: f64, b: f64) -> (f64, f64, f64) {
        // 1. Exposure: multiply by 2^exposure
        let exp_factor = 2.0f64.powf(self.exposure);
        let mut r = r * exp_factor;
        let mut g = g * exp_factor;
        let mut b = b * exp_factor;

        // 2. Temperature & Tint
        let temp_k = self.temperature / 100.0;
        let tint_k = self.tint / 100.0;
        r += temp_k * 0.1;
        b -= temp_k * 0.1;
        g -= tint_k * 0.1;

        // 3. Contrast: around 0.5 midpoint
        r = (r - 0.5) * self.contrast + 0.5;
        g = (g - 0.5) * self.contrast + 0.5;
        b = (b - 0.5) * self.contrast + 0.5;

        // 4. Shadows / Highlights
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        if luma < 0.5 {
            let shadow_boost = self.shadows * (1.0 - 2.0 * luma);
            r += shadow_boost;
            g += shadow_boost;
            b += shadow_boost;
        } else {
            let highlight_boost = self.highlights * (2.0 * (luma - 0.5));
            r += highlight_boost;
            g += highlight_boost;
            b += highlight_boost;
        }

        // 5. Saturation
        let luma_post = (0.2126 * r + 0.7152 * g + 0.0722 * b).clamp(0.0, 1.0);
        r = luma_post + (r - luma_post) * self.saturation;
        g = luma_post + (g - luma_post) * self.saturation;
        b = luma_post + (b - luma_post) * self.saturation;

        (r.clamp(0.0, 1.0), g.clamp(0.0, 1.0), b.clamp(0.0, 1.0))
    }
}

/// 3D LUT (Look-Up Table) for cinematic color grading
#[derive(Debug, Clone, PartialEq)]
pub struct Lut3D {
    pub size: usize,
    pub title: String,
    pub table: Vec<[f32; 3]>, // size^3 entries
}

impl Lut3D {
    pub fn parse_cube(content: &str) -> Result<Self, String> {
        let mut size = 0usize;
        let mut title = String::from("LUT");
        let mut table = Vec::new();

        for line in content.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            if line.starts_with("TITLE") {
                title = line.trim_start_matches("TITLE").trim().replace('"', "");
                continue;
            }
            if line.starts_with("LUT_3D_SIZE") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    size = parts[1]
                        .parse()
                        .map_err(|e| format!("Invalid LUT size: {}", e))?;
                }
                continue;
            }

            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() == 3 {
                let r: f32 = parts[0]
                    .parse()
                    .map_err(|e| format!("Bad float R: {}", e))?;
                let g: f32 = parts[1]
                    .parse()
                    .map_err(|e| format!("Bad float G: {}", e))?;
                let b: f32 = parts[2]
                    .parse()
                    .map_err(|e| format!("Bad float B: {}", e))?;
                table.push([r, g, b]);
            }
        }

        if size == 0 || table.len() != size * size * size {
            return Err(format!(
                "LUT table size mismatch: expected {} entries for size {}, found {}",
                size * size * size,
                size,
                table.len()
            ));
        }

        Ok(Self { size, title, table })
    }

    /// Trilinear interpolation through 3D LUT
    pub fn lookup(&self, r: f32, g: f32, b: f32) -> (f32, f32, f32) {
        let max_idx = (self.size - 1) as f32;
        let rf = (r.clamp(0.0, 1.0) * max_idx).clamp(0.0, max_idx);
        let gf = (g.clamp(0.0, 1.0) * max_idx).clamp(0.0, max_idx);
        let bf = (b.clamp(0.0, 1.0) * max_idx).clamp(0.0, max_idx);

        let r0 = rf.floor() as usize;
        let r1 = (r0 + 1).min(self.size - 1);
        let g0 = gf.floor() as usize;
        let g1 = (g0 + 1).min(self.size - 1);
        let b0 = bf.floor() as usize;
        let b1 = (b0 + 1).min(self.size - 1);

        let rd = rf - r0 as f32;
        let gd = gf - g0 as f32;
        let bd = bf - b0 as f32;

        let sample = |r_idx: usize, g_idx: usize, b_idx: usize| -> [f32; 3] {
            let idx = r_idx + g_idx * self.size + b_idx * self.size * self.size;
            self.table[idx]
        };

        let c000 = sample(r0, g0, b0);
        let c100 = sample(r1, g0, b0);
        let c010 = sample(r0, g1, b0);
        let c110 = sample(r1, g1, b0);
        let c001 = sample(r0, g0, b1);
        let c101 = sample(r1, g0, b1);
        let c011 = sample(r0, g1, b1);
        let c111 = sample(r1, g1, b1);

        let mut result = [0.0f32; 3];
        for ch in 0..3 {
            let c00 = c000[ch] * (1.0 - rd) + c100[ch] * rd;
            let c10 = c010[ch] * (1.0 - rd) + c110[ch] * rd;
            let c01 = c001[ch] * (1.0 - rd) + c101[ch] * rd;
            let c11 = c011[ch] * (1.0 - rd) + c111[ch] * rd;

            let c0 = c00 * (1.0 - gd) + c10 * gd;
            let c1 = c01 * (1.0 - gd) + c11 * gd;

            result[ch] = c0 * (1.0 - bd) + c1 * bd;
        }

        (result[0], result[1], result[2])
    }
}

/// Chroma Key (Green screen / Blue screen removal)
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ChromaKeyConfig {
    pub key_color_r: u8,
    pub key_color_g: u8,
    pub key_color_b: u8,
    pub similarity: f64,        // 0.0 to 1.0
    pub smoothness: f64,        // 0.0 to 1.0
    pub spill_suppression: f64, // 0.0 to 1.0
}

impl Default for ChromaKeyConfig {
    fn default() -> Self {
        Self {
            key_color_r: 0,
            key_color_g: 255,
            key_color_b: 0,
            similarity: 0.4,
            smoothness: 0.1,
            spill_suppression: 0.5,
        }
    }
}

impl ChromaKeyConfig {
    pub fn process_pixel(&self, r: u8, g: u8, b: u8, a: u8) -> (u8, u8, u8, u8) {
        let dr = (r as f64 - self.key_color_r as f64) / 255.0;
        let dg = (g as f64 - self.key_color_g as f64) / 255.0;
        let db = (b as f64 - self.key_color_b as f64) / 255.0;
        let distance = (dr * dr + dg * dg + db * db).sqrt();

        let mask = if distance < self.similarity {
            0.0
        } else if distance < self.similarity + self.smoothness {
            (distance - self.similarity) / self.smoothness.max(1e-5)
        } else {
            1.0
        };

        let new_a = ((a as f64 / 255.0) * mask * 255.0).round() as u8;

        // Spill suppression: reduce green/blue cast
        let out_g = if self.key_color_g > 200 && self.spill_suppression > 0.0 {
            let max_rb = r.max(b) as f64;
            let excess = (g as f64 - max_rb).max(0.0) * self.spill_suppression;
            (g as f64 - excess).round() as u8
        } else {
            g
        };

        (r, out_g, b, new_a)
    }
}
