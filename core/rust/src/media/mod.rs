use lru::LruCache;
use parking_lot::Mutex;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::num::NonZeroUsize;
use std::sync::atomic::{AtomicUsize, Ordering};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct VideoStreamInfo {
    pub index: u32,
    pub codec: String,
    pub width: u32,
    pub height: u32,
    pub fps_num: i64,
    pub fps_den: i64,
    pub total_frames: i64,
    pub pixel_format: String,
    pub bit_depth: u8,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AudioStreamInfo {
    pub index: u32,
    pub codec: String,
    pub sample_rate: u32,
    pub channels: u32,
    pub channel_layout: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SubtitleStreamInfo {
    pub index: u32,
    pub codec: String,
    pub language: Option<String>,
    pub title: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MediaInfo {
    pub file_path: String,
    pub format_name: String,
    pub duration_seconds: f64,
    pub file_size_bytes: u64,
    pub video_streams: Vec<VideoStreamInfo>,
    pub audio_streams: Vec<AudioStreamInfo>,
    pub subtitle_streams: Vec<SubtitleStreamInfo>,
}

impl MediaInfo {
    pub fn primary_video(&self) -> Option<&VideoStreamInfo> {
        self.video_streams.first()
    }
    pub fn primary_audio(&self) -> Option<&AudioStreamInfo> {
        self.audio_streams.first()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct FrameCacheKey {
    pub media_path: String,
    pub frame_number: i64,
    pub width: u32,
    pub height: u32,
}

#[derive(Debug, Clone)]
pub struct FrameBuffer {
    pub key: FrameCacheKey,
    pub width: u32,
    pub height: u32,
    pub data: Vec<u8>, // RGBA32
    pub pts_seconds: f64,
}

impl FrameBuffer {
    pub fn size_in_bytes(&self) -> usize {
        self.data.len()
    }
}

/// Thread-safe, memory-budgeted LRU cache for decoded video frames.
pub struct FrameCache {
    max_bytes: usize,
    current_bytes: AtomicUsize,
    cache: Mutex<LruCache<FrameCacheKey, FrameBuffer>>,
}

impl FrameCache {
    pub fn new(max_bytes: usize) -> Self {
        Self {
            max_bytes,
            current_bytes: AtomicUsize::new(0),
            cache: Mutex::new(LruCache::new(NonZeroUsize::new(1000).unwrap())),
        }
    }

    pub fn get(&self, key: &FrameCacheKey) -> Option<FrameBuffer> {
        let mut lock = self.cache.lock();
        lock.get(key).cloned()
    }

    pub fn insert(&self, frame: FrameBuffer) {
        let frame_size = frame.size_in_bytes();
        let mut lock = self.cache.lock();

        // Evict until within budget
        while self.current_bytes.load(Ordering::Relaxed) + frame_size > self.max_bytes && !lock.is_empty() {
            if let Some((_, popped)) = lock.pop_lru() {
                let popped_size = popped.size_in_bytes();
                self.current_bytes.fetch_sub(popped_size, Ordering::SeqCst);
            } else {
                break;
            }
        }

        self.current_bytes.fetch_add(frame_size, Ordering::SeqCst);
        lock.put(frame.key.clone(), frame);
    }

    pub fn current_bytes(&self) -> usize {
        self.current_bytes.load(Ordering::Relaxed)
    }

    pub fn max_bytes(&self) -> usize {
        self.max_bytes
    }

    pub fn clear(&self) {
        let mut lock = self.cache.lock();
        lock.clear();
        self.current_bytes.store(0, Ordering::SeqCst);
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ProxyConfig {
    pub target_width: u32,
    pub target_height: u32,
    pub codec: String,
    pub crf: u8,
}

impl Default for ProxyConfig {
    fn default() -> Self {
        Self {
            target_width: 1280,
            target_height: 720,
            codec: "libx264".into(),
            crf: 26,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ProxyStatus {
    Valid,
    Missing,
    Corrupted,
    NotRegistered,
}

pub struct ProxyManager {
    config: ProxyConfig,
    proxy_map: Mutex<HashMap<String, String>>,
    use_proxies: Mutex<bool>,
}

impl ProxyManager {
    pub fn new(config: ProxyConfig) -> Self {
        Self {
            config,
            proxy_map: Mutex::new(HashMap::new()),
            use_proxies: Mutex::new(true),
        }
    }

    pub fn should_generate_proxy(&self, info: &MediaInfo) -> bool {
        if let Some(video) = info.primary_video() {
            video.width > self.config.target_width || video.height > self.config.target_height
        } else {
            false
        }
    }

    pub fn register_proxy(&self, original_path: String, proxy_path: String) {
        self.proxy_map.lock().insert(original_path, proxy_path);
    }

    pub fn unregister_proxy(&self, original_path: &str) -> Option<String> {
        self.proxy_map.lock().remove(original_path)
    }

    pub fn check_proxy_status(&self, original_path: &str) -> ProxyStatus {
        let lock = self.proxy_map.lock();
        if let Some(proxy_path) = lock.get(original_path) {
            let path = std::path::Path::new(proxy_path);
            if !path.exists() {
                ProxyStatus::Missing
            } else if let Ok(meta) = std::fs::metadata(path) {
                if meta.len() == 0 {
                    ProxyStatus::Corrupted
                } else {
                    ProxyStatus::Valid
                }
            } else {
                ProxyStatus::Corrupted
            }
        } else {
            ProxyStatus::NotRegistered
        }
    }

    /// Returns the effective media path for editing/previewing.
    /// If proxies are enabled and the proxy is verified on disk, returns the proxy path.
    /// If the proxy is missing, corrupted, or proxies are disabled, safely falls back to original_path.
    pub fn get_effective_path(&self, original_path: &str) -> String {
        let enabled = *self.use_proxies.lock();
        if enabled {
            if self.check_proxy_status(original_path) == ProxyStatus::Valid {
                let lock = self.proxy_map.lock();
                if let Some(proxy) = lock.get(original_path) {
                    return proxy.clone();
                }
            }
        }
        original_path.to_string()
    }

    /// Always returns the pristine original source path for export rendering.
    pub fn get_export_path(&self, original_path: &str) -> String {
        original_path.to_string()
    }

    pub fn set_use_proxies(&self, use_proxies: bool) {
        *self.use_proxies.lock() = use_proxies;
    }

    pub fn is_using_proxies(&self) -> bool {
        *self.use_proxies.lock()
    }

    /// Evicts proxy file from disk and unregisters it.
    pub fn evict_proxy(&self, original_path: &str) -> Result<(), String> {
        if let Some(proxy_path) = self.unregister_proxy(original_path) {
            let p = std::path::Path::new(&proxy_path);
            if p.exists() {
                std::fs::remove_file(p).map_err(|e| e.to_string())?;
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_proxy_lifecycle_validation_and_fallback() {
        let mgr = ProxyManager::new(ProxyConfig::default());
        let temp_dir = std::env::temp_dir();
        let orig_file = temp_dir.join("test_orig.mp4");
        let proxy_file = temp_dir.join("test_proxy_valid.mp4");
        let corrupt_file = temp_dir.join("test_proxy_corrupt.mp4");

        std::fs::write(&orig_file, b"ORIGINAL_MEDIA_CONTENT_4K").unwrap();
        std::fs::write(&proxy_file, b"PROXY_MEDIA_CONTENT_720P").unwrap();
        std::fs::write(&corrupt_file, b"").unwrap(); // 0 bytes = corrupted

        let orig_str = orig_file.to_string_lossy().to_string();
        let proxy_str = proxy_file.to_string_lossy().to_string();
        let corrupt_str = corrupt_file.to_string_lossy().to_string();

        // 1. Unregistered status
        assert_eq!(mgr.check_proxy_status(&orig_str), ProxyStatus::NotRegistered);
        assert_eq!(mgr.get_effective_path(&orig_str), orig_str);

        // 2. Valid proxy registered
        mgr.register_proxy(orig_str.clone(), proxy_str.clone());
        assert_eq!(mgr.check_proxy_status(&orig_str), ProxyStatus::Valid);
        assert_eq!(mgr.get_effective_path(&orig_str), proxy_str);

        // 3. Export path must always use original media
        assert_eq!(mgr.get_export_path(&orig_str), orig_str);

        // 4. Corrupt proxy registered -> automatically falls back to original!
        let corrupt_orig = "test_corrupt_orig.mp4".to_string();
        mgr.register_proxy(corrupt_orig.clone(), corrupt_str.clone());
        assert_eq!(mgr.check_proxy_status(&corrupt_orig), ProxyStatus::Corrupted);
        assert_eq!(mgr.get_effective_path(&corrupt_orig), corrupt_orig);

        // 5. Deleted proxy -> automatically falls back to original!
        let _ = std::fs::remove_file(&proxy_file);
        assert_eq!(mgr.check_proxy_status(&orig_str), ProxyStatus::Missing);
        assert_eq!(mgr.get_effective_path(&orig_str), orig_str);

        // Cleanup
        let _ = std::fs::remove_file(&orig_file);
        let _ = std::fs::remove_file(&corrupt_file);
    }
}

