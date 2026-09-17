#![allow(unknown_lints)]
#![allow(clippy::chunks_exact_to_as_chunks)]
#![allow(clippy::not_unsafe_ptr_arg_deref)]

pub mod audio;
pub mod automation;
pub mod effects;
pub mod ffi;
pub mod graph;
pub mod media;
pub mod multicam;
pub mod project;
pub mod render;
pub mod subtitles;
pub mod timeline;
pub mod undo;

pub use audio::{calculate_integrated_lufs, extract_waveform, AudioBuffer, Compressor, Equalizer};
pub use automation::{calculate_reframe_crop, detect_scene_cuts, detect_silence};
pub use effects::{ChromaKeyConfig, ColorGradingConfig, Lut3D};
pub use graph::{ImageCanvas, RgbaPixel};
pub use media::{FrameBuffer, FrameCache, MediaInfo, ProxyManager};
pub use multicam::{find_audio_sync_lag, MulticamAngle, MulticamGroup, SyncMethod};
pub use project::{AssetMetadata, Project, RenderSettings};
pub use render::{
    build_ffmpeg_render_args, HardwareCapabilities, JobStatus, RenderJob, RenderQueue,
};
pub use subtitles::{SubtitleCue, SubtitleTrack};
pub use timeline::{
    BlendMode, Clip, RationalTime, TimecodeConfig, Timeline, Track, TrackType, Transform,
};
pub use undo::{Action, UndoStack};
