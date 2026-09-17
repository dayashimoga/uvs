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

    pub fn get_effective_path(&self, original_path: &str) -> String {
        let enabled = *self.use_proxies.lock();
        if enabled {
            if let Some(proxy) = self.proxy_map.lock().get(original_path) {
                return proxy.clone();
            }
        }
        original_path.to_string()
    }

    pub fn set_use_proxies(&self, use_proxies: bool) {
        *self.use_proxies.lock() = use_proxies;
    }

    pub fn is_using_proxies(&self) -> bool {
        *self.use_proxies.lock()
    }
}
