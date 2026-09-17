use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};
use uuid::Uuid;

use crate::project::RenderSettings;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum HardwareVendor {
    NvidiaNvenc,
    IntelQsv,
    AmdAmf,
    LinuxVaapi,
    AppleVideoToolbox,
    AndroidMediaCodec,
    NoneCpuOnly,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct HardwareCapabilities {
    pub primary_vendor: HardwareVendor,
    pub supports_h264_hw: bool,
    pub supports_hevc_hw: bool,
    pub supports_av1_hw: bool,
    pub recommended_h264_encoder: String,
    pub recommended_hevc_encoder: String,
    pub classification: String,
}

impl HardwareCapabilities {
    pub fn detect() -> Self {
        #[cfg(target_os = "windows")]
        {
            Self {
                primary_vendor: HardwareVendor::NoneCpuOnly,
                supports_h264_hw: true,
                supports_hevc_hw: true,
                supports_av1_hw: false,
                recommended_h264_encoder: "libx264".into(),
                recommended_hevc_encoder: "libx265".into(),
                classification: "PROVEN".into(),
            }
        }
        #[cfg(target_os = "macos")]
        {
            Self {
                primary_vendor: HardwareVendor::AppleVideoToolbox,
                supports_h264_hw: true,
                supports_hevc_hw: true,
                supports_av1_hw: false,
                recommended_h264_encoder: "h264_videotoolbox".into(),
                recommended_hevc_encoder: "hevc_videotoolbox".into(),
                classification: "HARDWARE-REQUIRED".into(),
            }
        }
        #[cfg(target_os = "android")]
        {
            Self {
                primary_vendor: HardwareVendor::AndroidMediaCodec,
                supports_h264_hw: true,
                supports_hevc_hw: true,
                supports_av1_hw: false,
                recommended_h264_encoder: "h264_mediacodec".into(),
                recommended_hevc_encoder: "hevc_mediacodec".into(),
                classification: "HARDWARE-REQUIRED".into(),
            }
        }
        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "android")))]
        {
            Self {
                primary_vendor: HardwareVendor::NoneCpuOnly,
                supports_h264_hw: false,
                supports_hevc_hw: false,
                supports_av1_hw: false,
                recommended_h264_encoder: "libx264".into(),
                recommended_hevc_encoder: "libx265".into(),
                classification: "EMULATOR-PROVEN".into(),
            }
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum JobStatus {
    Queued,
    Rendering,
    Paused,
    Completed,
    Failed,
    Cancelled,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RenderJob {
    pub id: String,
    pub name: String,
    pub output_path: String,
    pub status: JobStatus,
    pub progress: f64,
    pub current_frame: i64,
    pub total_frames: i64,
    pub estimated_seconds_remaining: f64,
    pub settings: RenderSettings,
    pub error_message: Option<String>,
}

impl RenderJob {
    pub fn new(
        name: impl Into<String>,
        output_path: impl Into<String>,
        total_frames: i64,
        settings: RenderSettings,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name: name.into(),
            output_path: output_path.into(),
            status: JobStatus::Queued,
            progress: 0.0,
            current_frame: 0,
            total_frames,
            estimated_seconds_remaining: 0.0,
            settings,
            error_message: None,
        }
    }
}

pub struct RenderQueue {
    jobs: Arc<Mutex<Vec<RenderJob>>>,
}

impl Default for RenderQueue {
    fn default() -> Self {
        Self::new()
    }
}

impl RenderQueue {
    pub fn new() -> Self {
        Self {
            jobs: Arc::new(Mutex::new(Vec::new())),
        }
    }

    pub fn add_job(&self, job: RenderJob) -> String {
        let id = job.id.clone();
        self.jobs.lock().unwrap().push(job);
        id
    }

    pub fn get_job(&self, id: &str) -> Option<RenderJob> {
        self.jobs
            .lock()
            .unwrap()
            .iter()
            .find(|j| j.id == id)
            .cloned()
    }

    pub fn list_jobs(&self) -> Vec<RenderJob> {
        self.jobs.lock().unwrap().clone()
    }

    pub fn update_progress(&self, id: &str, current_frame: i64, progress: f64, eta: f64) {
        let mut lock = self.jobs.lock().unwrap();
        if let Some(job) = lock.iter_mut().find(|j| j.id == id) {
            job.current_frame = current_frame;
            job.progress = progress.clamp(0.0, 1.0);
            job.estimated_seconds_remaining = eta;
            if progress >= 1.0 {
                job.status = JobStatus::Completed;
            } else if job.status == JobStatus::Queued {
                job.status = JobStatus::Rendering;
            }
        }
    }

    pub fn set_status(&self, id: &str, status: JobStatus, error: Option<String>) {
        let mut lock = self.jobs.lock().unwrap();
        if let Some(job) = lock.iter_mut().find(|j| j.id == id) {
            job.status = status;
            job.error_message = error;
        }
    }

    pub fn cancel_job(&self, id: &str) {
        self.set_status(id, JobStatus::Cancelled, None);
    }
}

pub fn build_ffmpeg_render_args(
    input_video: &str,
    output_path: &str,
    settings: &RenderSettings,
    caps: &HardwareCapabilities,
) -> Vec<String> {
    let mut args = vec!["-y".to_string(), "-i".to_string(), input_video.to_string()];

    let video_codec = if settings.use_hardware_accel
        && caps.supports_h264_hw
        && settings.video_codec == "h264"
    {
        &caps.recommended_h264_encoder
    } else if settings.use_hardware_accel && caps.supports_hevc_hw && settings.video_codec == "hevc"
    {
        &caps.recommended_hevc_encoder
    } else {
        match settings.video_codec.as_str() {
            "h264" => "libx264",
            "hevc" => "libx265",
            "vp9" => "libvpx-vp9",
            "av1" => "libsvtav1",
            _ => "libx264",
        }
    };

    args.extend([
        "-c:v".to_string(),
        video_codec.to_string(),
        "-b:v".to_string(),
        format!("{}k", settings.video_bitrate_kbps),
        "-vf".to_string(),
        format!("scale={}:{}", settings.width, settings.height),
        "-r".to_string(),
        format!("{}/{}", settings.fps_num, settings.fps_den),
    ]);

    let audio_codec = match settings.audio_codec.as_str() {
        "aac" => "aac",
        "opus" => "libopus",
        "mp3" => "libmp3lame",
        "pcm" => "pcm_s16le",
        _ => "aac",
    };

    args.extend([
        "-c:a".to_string(),
        audio_codec.to_string(),
        "-b:a".to_string(),
        format!("{}k", settings.audio_bitrate_kbps),
        output_path.to_string(),
    ]);

    args
}

pub fn execute_ffmpeg_render(
    input_video: &str,
    output_path: &str,
    settings: &RenderSettings,
    caps: &HardwareCapabilities,
) -> Result<String, String> {
    let args = build_ffmpeg_render_args(input_video, output_path, settings, caps);
    let output = std::process::Command::new("ffmpeg")
        .args(&args)
        .output()
        .map_err(|e| format!("Failed to spawn ffmpeg: {}", e))?;

    if output.status.success() {
        Ok(format!("Render completed successfully to {}", output_path))
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(format!(
            "FFmpeg failed with exit code {:?}: {}",
            output.status.code(),
            stderr
        ))
    }
}
