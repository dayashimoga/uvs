use crate::timeline::RationalTime;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SubtitleCue {
    pub id: u32,
    pub start_time: RationalTime,
    pub end_time: RationalTime,
    pub text: String,
    pub style: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SubtitleTrack {
    pub language: String,
    pub title: String,
    pub cues: Vec<SubtitleCue>,
}

impl SubtitleTrack {
    pub fn new(language: impl Into<String>, title: impl Into<String>) -> Self {
        Self {
            language: language.into(),
            title: title.into(),
            cues: Vec::new(),
        }
    }

    pub fn add_cue(&mut self, cue: SubtitleCue) {
        self.cues.push(cue);
        self.cues.sort_by(|a, b| a.start_time.cmp(&b.start_time));
    }

    pub fn cue_at(&self, time: RationalTime) -> Option<&SubtitleCue> {
        self.cues.iter().find(|c| time >= c.start_time && time <= c.end_time)
    }

    pub fn shift(&mut self, offset: RationalTime) {
        for cue in &mut self.cues {
            cue.start_time = cue.start_time + offset;
            cue.end_time = cue.end_time + offset;
        }
    }

    /// Parse SubRip (SRT) format
    pub fn parse_srt(content: &str, language: &str, title: &str) -> Result<Self, String> {
        let mut track = Self::new(language, title);
        let blocks = content.replace("\r\n", "\n").replace('\r', "\n");
        let raw_cues: Vec<&str> = blocks.split("\n\n").collect();

        for block in raw_cues {
            let lines: Vec<&str> = block.lines().map(|l| l.trim()).filter(|l| !l.is_empty()).collect();
            if lines.len() < 2 {
                continue;
            }

            let (time_idx, id) = if let Ok(id_val) = lines[0].parse::<u32>() {
                (1, id_val)
            } else {
                (0, (track.cues.len() + 1) as u32)
            };

            if time_idx >= lines.len() || !lines[time_idx].contains("-->") {
                continue;
            }

            let times: Vec<&str> = lines[time_idx].split("-->").map(|s| s.trim()).collect();
            if times.len() != 2 {
                continue;
            }

            let start = parse_srt_time(times[0])?;
            let end = parse_srt_time(times[1])?;
            let text = lines[time_idx + 1..].join("\n");

            track.add_cue(SubtitleCue {
                id,
                start_time: start,
                end_time: end,
                text,
                style: None,
            });
        }

        Ok(track)
    }

    /// Format to SubRip (SRT) string
    pub fn to_srt(&self) -> String {
        let mut out = String::new();
        for (i, cue) in self.cues.iter().enumerate() {
            out.push_str(&format!("{}\n", i + 1));
            out.push_str(&format!("{} --> {}\n", format_srt_time(cue.start_time), format_srt_time(cue.end_time)));
            out.push_str(&format!("{}\n\n", cue.text));
        }
        out
    }

    /// Format to WebVTT string
    pub fn to_vtt(&self) -> String {
        let mut out = String::from("WEBVTT\n\n");
        for (i, cue) in self.cues.iter().enumerate() {
            out.push_str(&format!("{}\n", i + 1));
            out.push_str(&format!("{} --> {}\n", format_vtt_time(cue.start_time), format_vtt_time(cue.end_time)));
            out.push_str(&format!("{}\n\n", cue.text));
        }
        out
    }
}

fn parse_srt_time(s: &str) -> Result<RationalTime, String> {
    // 00:01:23,456 or 00:01:23.456
    let s = s.replace(',', ".");
    let parts: Vec<&str> = s.split(':').collect();
    if parts.len() != 3 {
        return Err(format!("Invalid time string: {}", s));
    }
    let h: f64 = parts[0].parse().map_err(|e| format!("Hours: {}", e))?;
    let m: f64 = parts[1].parse().map_err(|e| format!("Mins: {}", e))?;
    let sec: f64 = parts[2].parse().map_err(|e| format!("Secs: {}", e))?;
    let total = h * 3600.0 + m * 60.0 + sec;
    Ok(RationalTime::from_f64(total))
}

fn format_srt_time(t: RationalTime) -> String {
    let mut total_ms = (t.as_f64() * 1000.0).round() as i64;
    if total_ms < 0 { total_ms = 0; }
    let ms = total_ms % 1000;
    let s = (total_ms / 1000) % 60;
    let m = (total_ms / 60000) % 60;
    let h = total_ms / 3600000;
    format!("{:02}:{:02}:{:02},{:03}", h, m, s, ms)
}

fn format_vtt_time(t: RationalTime) -> String {
    let mut total_ms = (t.as_f64() * 1000.0).round() as i64;
    if total_ms < 0 { total_ms = 0; }
    let ms = total_ms % 1000;
    let s = (total_ms / 1000) % 60;
    let m = (total_ms / 60000) % 60;
    let h = total_ms / 3600000;
    format!("{:02}:{:02}:{:02}.{:03}", h, m, s, ms)
}
