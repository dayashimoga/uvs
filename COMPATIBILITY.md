# Codec & Platform Compatibility Matrix

Universal Video Studio is engineered for wide cross-platform compatibility across desktop and mobile architectures.

---

## 1. Operating System Support

| Platform | Minimum Version | Target Architecture | Audio Subsystem | Hardware Video Acceleration |
| :--- | :--- | :--- | :--- | :--- |
| **Windows** | Windows 10 (1809+) | x86_64, ARM64 | WASAPI, DirectSound | NVENC, Intel QSV, AMD AMF, Direct3D11 |
| **Linux** | Ubuntu 22.04+ / Fedora 38+ | x86_64, aarch64 | ALSA, PulseAudio, PipeWire | VAAPI, NVENC, Vulkan Video |
| **Android** | Android 9.0 (API 28+) | arm64-v8a, armeabi-v7a | AAudio, OpenSL ES | MediaCodec NDK, OpenMAX |
| **macOS** | macOS 12 Monterey+ | Apple Silicon (M1..M4), Intel | CoreAudio | Apple VideoToolbox, Metal |

---

## 2. Container & Codec Matrix

### 2.1 Video Codecs
| Codec | Decoding | Encoding | HW Acceleration | SW Fallback |
| :--- | :---: | :---: | :--- | :--- |
| **H.264 / AVC** | Yes | Yes | NVENC, QSV, AMF, VideoToolbox, MediaCodec | `libx264` |
| **H.265 / HEVC**| Yes | Yes | NVENC, QSV, AMF, VideoToolbox, MediaCodec | `libx265` |
| **VP9** | Yes | Yes | QSV, VAAPI | `libvpx-vp9` |
| **AV1** | Yes | Yes | NVENC (40-series), QSV, Apple M3/M4 | `libsvtav1`, `libdav1d` |
| **Apple ProRes**| Yes | Yes | VideoToolbox | `prores_ks` (CPU) |
| **DNxHR / DNxHD**| Yes | Yes | N/A | FFmpeg native |

### 2.2 Audio Codecs
| Codec | Decoding | Encoding | Sample Rates Supported |
| :--- | :---: | :---: | :--- |
| **AAC** | Yes | Yes | 44.1kHz, 48kHz, 96kHz |
| **Opus** | Yes | Yes | 48kHz native |
| **MP3** | Yes | Yes | 44.1kHz, 48kHz |
| **FLAC** | Yes | Yes | 44.1kHz – 192kHz (Lossless) |
| **PCM (WAV)** | Yes | Yes | 16-bit, 24-bit, 32-bit Float |

### 2.3 Containers & Streaming Protocols
* **Containers**: MP4, MKV, WebM, MOV, TS, M2TS, AVI, FLV, OGG.
* **Network Protocols**: RTSP, HLS (`.m3u8`), HTTP/HTTPS progressive, RTMP, UDP/RTP multicast.
* **Subtitles**: SubRip (`.srt`), WebVTT (`.vtt`), SubStation Alpha (`.ass` / `.ssa`), Embedded MP4/MKV tracks.
