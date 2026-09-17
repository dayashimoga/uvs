use crate::timeline::{BlendMode, Transform};

#[derive(Debug, Clone, PartialEq)]
pub struct RgbaPixel {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

impl RgbaPixel {
    pub fn new(r: u8, g: u8, b: u8, a: u8) -> Self {
        Self { r, g, b, a }
    }

    pub fn blend(&self, top: &RgbaPixel, mode: BlendMode, opacity: f64) -> RgbaPixel {
        let alpha_top = (top.a as f64 / 255.0) * opacity.clamp(0.0, 1.0);
        if alpha_top <= 0.0 {
            return self.clone();
        }

        let r_bot = self.r as f64 / 255.0;
        let g_bot = self.g as f64 / 255.0;
        let b_bot = self.b as f64 / 255.0;
        let a_bot = self.a as f64 / 255.0;

        let r_top = top.r as f64 / 255.0;
        let g_top = top.g as f64 / 255.0;
        let b_top = top.b as f64 / 255.0;

        let (r_res, g_res, b_res) = match mode {
            BlendMode::Normal => (r_top, g_top, b_top),
            BlendMode::Add => (
                (r_bot + r_top).min(1.0),
                (g_bot + g_top).min(1.0),
                (b_bot + b_top).min(1.0),
            ),
            BlendMode::Multiply => (r_bot * r_top, g_bot * g_top, b_bot * b_top),
            BlendMode::Screen => (
                1.0 - (1.0 - r_bot) * (1.0 - r_top),
                1.0 - (1.0 - g_bot) * (1.0 - g_top),
                1.0 - (1.0 - b_bot) * (1.0 - b_top),
            ),
            BlendMode::Overlay => {
                let overlay_ch = |b: f64, t: f64| {
                    if b < 0.5 {
                        2.0 * b * t
                    } else {
                        1.0 - 2.0 * (1.0 - b) * (1.0 - t)
                    }
                };
                (
                    overlay_ch(r_bot, r_top),
                    overlay_ch(g_bot, g_top),
                    overlay_ch(b_bot, b_top),
                )
            }
        };

        // Standard alpha blending
        let out_a = alpha_top + a_bot * (1.0 - alpha_top);
        if out_a <= 0.0 {
            return RgbaPixel::new(0, 0, 0, 0);
        }

        let out_r = ((r_res * alpha_top + r_bot * a_bot * (1.0 - alpha_top)) / out_a) * 255.0;
        let out_g = ((g_res * alpha_top + g_bot * a_bot * (1.0 - alpha_top)) / out_a) * 255.0;
        let out_b = ((b_res * alpha_top + b_bot * a_bot * (1.0 - alpha_top)) / out_a) * 255.0;

        RgbaPixel::new(
            out_r.clamp(0.0, 255.0).round() as u8,
            out_g.clamp(0.0, 255.0).round() as u8,
            out_b.clamp(0.0, 255.0).round() as u8,
            (out_a * 255.0).clamp(0.0, 255.0).round() as u8,
        )
    }
}

pub struct ImageCanvas {
    pub width: u32,
    pub height: u32,
    pub data: Vec<u8>, // RGBA 4 bytes per pixel
}

impl ImageCanvas {
    pub fn new(width: u32, height: u32) -> Self {
        let size = (width * height * 4) as usize;
        Self {
            width,
            height,
            data: vec![0; size],
        }
    }

    pub fn clear(&mut self, r: u8, g: u8, b: u8, a: u8) {
        for chunk in self.data.as_chunks_mut::<4>().0 {
            chunk[0] = r;
            chunk[1] = g;
            chunk[2] = b;
            chunk[3] = a;
        }
    }

    pub fn get_pixel(&self, x: u32, y: u32) -> Option<RgbaPixel> {
        if x >= self.width || y >= self.height {
            return None;
        }
        let idx = ((y * self.width + x) * 4) as usize;
        Some(RgbaPixel::new(
            self.data[idx],
            self.data[idx + 1],
            self.data[idx + 2],
            self.data[idx + 3],
        ))
    }

    pub fn set_pixel(&mut self, x: u32, y: u32, pixel: RgbaPixel) {
        if x >= self.width || y >= self.height {
            return;
        }
        let idx = ((y * self.width + x) * 4) as usize;
        self.data[idx] = pixel.r;
        self.data[idx + 1] = pixel.g;
        self.data[idx + 2] = pixel.b;
        self.data[idx + 3] = pixel.a;
    }

    /// Composite a source image onto this canvas applying transform, opacity, and blend mode.
    pub fn composite_source(
        &mut self,
        source: &ImageCanvas,
        transform: &Transform,
        opacity: f64,
        mode: BlendMode,
    ) {
        if opacity <= 0.0 || transform.scale_x.abs() < 1e-6 || transform.scale_y.abs() < 1e-6 {
            return;
        }

        let inv_scale_x = 1.0 / transform.scale_x;
        let inv_scale_y = 1.0 / transform.scale_y;

        // Crop bounding in source space
        let crop_min_x = (transform.crop_left * source.width as f64).round() as u32;
        let crop_max_x = ((1.0 - transform.crop_right) * source.width as f64).round() as u32;
        let crop_min_y = (transform.crop_top * source.height as f64).round() as u32;
        let crop_max_y = ((1.0 - transform.crop_bottom) * source.height as f64).round() as u32;

        let center_x = self.width as f64 * 0.5 + transform.position_x;
        let center_y = self.height as f64 * 0.5 + transform.position_y;
        let src_anchor_x = source.width as f64 * transform.anchor_x;
        let src_anchor_y = source.height as f64 * transform.anchor_y;

        for y in 0..self.height {
            let dy = y as f64 - center_y;
            let sy_f = src_anchor_y + dy * inv_scale_y;
            if sy_f < crop_min_y as f64 || sy_f >= crop_max_y as f64 {
                continue;
            }
            let sy = sy_f as u32;
            if sy >= source.height {
                continue;
            }

            for x in 0..self.width {
                let dx = x as f64 - center_x;
                let sx_f = src_anchor_x + dx * inv_scale_x;
                if sx_f < crop_min_x as f64 || sx_f >= crop_max_x as f64 {
                    continue;
                }
                let sx = sx_f as u32;
                if sx >= source.width {
                    continue;
                }

                if let Some(src_px) = source.get_pixel(sx, sy) {
                    if src_px.a == 0 {
                        continue;
                    }
                    let dest_px = self.get_pixel(x, y).unwrap();
                    let blended = dest_px.blend(&src_px, mode, opacity);
                    self.set_pixel(x, y, blended);
                }
            }
        }
    }
}
