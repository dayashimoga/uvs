use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use uuid::Uuid;

use crate::timeline::{TimecodeConfig, Timeline};

pub const CURRENT_SCHEMA_VERSION: u32 = 1;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AssetMetadata {
    pub id: String,
    pub original_path: String,
    pub resolved_path: String,
    pub file_size: u64,
    pub sha256: String,
    pub duration_seconds: f64,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub fps: Option<f64>,
    pub audio_channels: Option<u32>,
    pub sample_rate: Option<u32>,
    pub proxy_path: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RenderSettings {
    pub output_format: String, // "mp4", "mkv", "mov", "webm"
    pub video_codec: String,   // "h264", "hevc", "vp9", "av1", "prores"
    pub audio_codec: String,   // "aac", "opus", "mp3", "pcm"
    pub width: u32,
    pub height: u32,
    pub fps_num: i64,
    pub fps_den: i64,
    pub video_bitrate_kbps: u32,
    pub audio_bitrate_kbps: u32,
    pub use_hardware_accel: bool,
}

impl Default for RenderSettings {
    fn default() -> Self {
        Self {
            output_format: "mp4".into(),
            video_codec: "h264".into(),
            audio_codec: "aac".into(),
            width: 1920,
            height: 1080,
            fps_num: 30,
            fps_den: 1,
            video_bitrate_kbps: 8000,
            audio_bitrate_kbps: 192,
            use_hardware_accel: true,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Project {
    pub id: String,
    pub name: String,
    pub schema_version: u32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub timeline: Timeline,
    pub render_settings: RenderSettings,
    pub assets: Vec<AssetMetadata>,
    pub metadata: HashMap<String, String>,
}

impl Project {
    pub fn new(
        name: impl Into<String>,
        width: u32,
        height: u32,
        timecode_config: TimecodeConfig,
    ) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4().to_string(),
            name: name.into(),
            schema_version: CURRENT_SCHEMA_VERSION,
            created_at: now,
            updated_at: now,
            timeline: Timeline::new(width, height, timecode_config),
            render_settings: RenderSettings {
                width,
                height,
                fps_num: timecode_config.num,
                fps_den: timecode_config.den,
                ..Default::default()
            },
            assets: Vec::new(),
            metadata: HashMap::new(),
        }
    }

    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string_pretty(self)
    }

    pub fn from_json(json_str: &str) -> Result<Self, String> {
        let mut proj: Project =
            serde_json::from_str(json_str).map_err(|e| format!("JSON parse error: {}", e))?;
        if proj.schema_version > CURRENT_SCHEMA_VERSION {
            return Err(format!(
                "Project schema version {} is newer than supported version {}",
                proj.schema_version, CURRENT_SCHEMA_VERSION
            ));
        }
        proj.schema_version = CURRENT_SCHEMA_VERSION;
        Ok(proj)
    }

    /// Atomic file save: writes to temp file first, then atomically renames to target path.
    pub fn save_atomic(&mut self, target_path: &Path) -> Result<(), String> {
        self.updated_at = Utc::now();
        let json_data = self.to_json().map_err(|e| e.to_string())?;

        let parent_dir = target_path.parent().unwrap_or_else(|| Path::new("."));
        fs::create_dir_all(parent_dir).map_err(|e| format!("Failed to create directory: {}", e))?;

        let temp_path = target_path.with_extension(format!("tmp.{}", Uuid::new_v4()));
        {
            let mut file = File::create(&temp_path)
                .map_err(|e| format!("Failed to create temp file: {}", e))?;
            file.write_all(json_data.as_bytes())
                .map_err(|e| format!("Failed to write temp file: {}", e))?;
            file.sync_all()
                .map_err(|e| format!("Failed to sync temp file: {}", e))?;
        }

        fs::rename(&temp_path, target_path).map_err(|e| {
            let _ = fs::remove_file(&temp_path);
            format!("Failed to rename temp file to target: {}", e)
        })?;

        Ok(())
    }

    pub fn load_from_file(path: &Path) -> Result<Self, String> {
        let mut file =
            File::open(path).map_err(|e| format!("Failed to open project file: {}", e))?;
        let mut contents = String::new();
        file.read_to_string(&mut contents)
            .map_err(|e| format!("Failed to read project file: {}", e))?;
        Self::from_json(&contents)
    }

    /// Autosave recovery: writes to `<project_dir>/.uvsp.recovery`
    pub fn save_recovery(&self, recovery_path: &Path) -> Result<(), String> {
        let json_data = self.to_json().map_err(|e| e.to_string())?;
        let mut file = File::create(recovery_path)
            .map_err(|e| format!("Failed to create recovery file: {}", e))?;
        file.write_all(json_data.as_bytes())
            .map_err(|e| format!("Failed to write recovery file: {}", e))?;
        file.sync_all()
            .map_err(|e| format!("Failed to sync recovery file: {}", e))?;
        Ok(())
    }

    /// Relink missing assets by scanning candidate search directories.
    pub fn relink_missing_assets(&mut self, search_dirs: &[PathBuf]) -> Vec<String> {
        let mut relinked = Vec::new();
        for asset in &mut self.assets {
            let p = Path::new(&asset.resolved_path);
            if p.exists() {
                continue;
            }

            let file_name = Path::new(&asset.original_path).file_name();
            if let Some(target_name) = file_name {
                let mut found = false;
                for dir in search_dirs {
                    if let Ok(entries) = fs::read_dir(dir) {
                        for entry in entries.flatten() {
                            let path = entry.path();
                            if path.is_file() && path.file_name() == Some(target_name) {
                                asset.resolved_path = path.to_string_lossy().to_string();
                                relinked.push(asset.id.clone());
                                found = true;
                                break;
                            }
                        }
                    }
                    if found {
                        break;
                    }
                }
            }
        }
        relinked
    }
}
