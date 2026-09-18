use num_rational::Rational64;
use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct TimecodeConfig {
    pub num: i64,
    pub den: i64,
    pub drop_frame: bool,
}

impl TimecodeConfig {
    pub fn fps_24() -> Self {
        Self {
            num: 24,
            den: 1,
            drop_frame: false,
        }
    }
    pub fn fps_23_976() -> Self {
        Self {
            num: 24000,
            den: 1001,
            drop_frame: false,
        }
    }
    pub fn fps_25() -> Self {
        Self {
            num: 25,
            den: 1,
            drop_frame: false,
        }
    }
    pub fn fps_30() -> Self {
        Self {
            num: 30,
            den: 1,
            drop_frame: false,
        }
    }
    pub fn fps_29_97() -> Self {
        Self {
            num: 30000,
            den: 1001,
            drop_frame: true,
        }
    }
    pub fn fps_60() -> Self {
        Self {
            num: 60,
            den: 1,
            drop_frame: false,
        }
    }
    pub fn fps_59_94() -> Self {
        Self {
            num: 60000,
            den: 1001,
            drop_frame: true,
        }
    }

    pub fn as_rational(&self) -> Rational64 {
        Rational64::new(self.num, self.den)
    }

    pub fn fps_float(&self) -> f64 {
        self.num as f64 / self.den as f64
    }
}

impl Default for TimecodeConfig {
    fn default() -> Self {
        Self::fps_30()
    }
}

/// Exact rational time representation in seconds.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize)]
pub struct RationalTime {
    pub seconds: Rational64,
}

impl<'de> serde::Deserialize<'de> for RationalTime {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        #[derive(Deserialize)]
        #[serde(untagged)]
        enum TimeHelper {
            Float(f64),
            Int(i64),
            Struct { seconds: Rational64 },
        }

        match TimeHelper::deserialize(deserializer)? {
            TimeHelper::Float(f) => Ok(RationalTime::from_f64(f)),
            TimeHelper::Int(i) => Ok(RationalTime::from_seconds(i, 1)),
            TimeHelper::Struct { seconds } => Ok(RationalTime { seconds }),
        }
    }
}

impl RationalTime {
    pub fn zero() -> Self {
        Self {
            seconds: Rational64::new(0, 1),
        }
    }

    pub fn from_seconds(num: i64, den: i64) -> Self {
        Self {
            seconds: Rational64::new(num, den),
        }
    }

    pub fn from_f64(sec: f64) -> Self {
        let den = 10_000_000i64;
        let num = (sec * den as f64).round() as i64;
        Self {
            seconds: Rational64::new(num, den),
        }
    }

    pub fn as_f64(&self) -> f64 {
        *self.seconds.numer() as f64 / *self.seconds.denom() as f64
    }

    pub fn from_frames(frame: i64, config: TimecodeConfig) -> Self {
        let fps = config.as_rational();
        Self {
            seconds: Rational64::new(frame, 1) / fps,
        }
    }

    pub fn to_frames(&self, config: TimecodeConfig) -> i64 {
        let fps = config.as_rational();
        let total_frames = self.seconds * fps;
        (total_frames.numer() + total_frames.denom() / 2) / total_frames.denom()
    }

    pub fn to_timecode_string(&self, config: TimecodeConfig) -> String {
        let mut total_frames = self.to_frames(config);
        if total_frames < 0 {
            total_frames = 0;
        }

        if config.drop_frame && (config.num == 30000 && config.den == 1001) {
            // SMPTE drop frame calculation for 29.97fps:
            // Drop 2 frames at the start of every minute, except minutes 00, 10, 20, 30, 40, 50.
            let frames_per_10m = 17982i64; // 10 * 60 * 30 - 18
            let frames_per_min = 1798i64; // 60 * 30 - 2

            let d = total_frames / frames_per_10m;
            let m = total_frames % frames_per_10m;

            let drop_frames = if m > 2 {
                2 * ((m - 2) / frames_per_min)
            } else {
                0
            };

            let calculated_frames = total_frames + 18 * d + drop_frames;
            let frames = calculated_frames % 30;
            let seconds = (calculated_frames / 30) % 60;
            let minutes = (calculated_frames / 1800) % 60;
            let hours = calculated_frames / 108000;

            format!("{:02}:{:02}:{:02};{:02}", hours, minutes, seconds, frames)
        } else {
            let fps_int = (config.fps_float().round()) as i64;
            let fps_int = if fps_int <= 0 { 30 } else { fps_int };

            let frames = total_frames % fps_int;
            let total_seconds = total_frames / fps_int;
            let seconds = total_seconds % 60;
            let minutes = (total_seconds / 60) % 60;
            let hours = total_seconds / 3600;

            format!("{:02}:{:02}:{:02}:{:02}", hours, minutes, seconds, frames)
        }
    }

    pub fn parse_timecode(tc: &str, config: TimecodeConfig) -> Result<Self, String> {
        let is_df = tc.contains(';');
        let parts: Vec<&str> = tc.split([':', ';']).collect();
        if parts.len() != 4 {
            return Err(format!(
                "Invalid timecode format: '{}', expected HH:MM:SS:FF",
                tc
            ));
        }

        let hours: i64 = parts[0]
            .parse()
            .map_err(|e| format!("Invalid hours: {}", e))?;
        let minutes: i64 = parts[1]
            .parse()
            .map_err(|e| format!("Invalid minutes: {}", e))?;
        let seconds: i64 = parts[2]
            .parse()
            .map_err(|e| format!("Invalid seconds: {}", e))?;
        let frames: i64 = parts[3]
            .parse()
            .map_err(|e| format!("Invalid frames: {}", e))?;

        if is_df || config.drop_frame {
            let total_minutes = hours * 60 + minutes;
            let total_frames = hours * 108000 + minutes * 1800 + seconds * 30 + frames
                - 2 * (total_minutes - total_minutes / 10);
            Ok(Self::from_frames(total_frames, config))
        } else {
            let fps_int = (config.fps_float().round()) as i64;
            let total_frames = ((hours * 3600 + minutes * 60 + seconds) * fps_int) + frames;
            Ok(Self::from_frames(total_frames, config))
        }
    }
}

impl std::ops::Add for RationalTime {
    type Output = Self;
    fn add(self, rhs: Self) -> Self::Output {
        Self {
            seconds: self.seconds + rhs.seconds,
        }
    }
}

impl std::ops::Sub for RationalTime {
    type Output = Self;
    fn sub(self, rhs: Self) -> Self::Output {
        Self {
            seconds: self.seconds - rhs.seconds,
        }
    }
}

impl fmt::Display for RationalTime {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:.3}s", self.as_f64())
    }
}
