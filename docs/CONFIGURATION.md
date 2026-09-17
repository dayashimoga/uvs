# Configuration & Settings

Universal Video Studio provides environment variables and project configuration options to tailor performance for low-resource or high-end workstations.

---

## 1. Environment Variables

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `UVS_FRAME_CACHE_MB` | `512` | Maximum RAM (in MB) allocated to the decoded frame pool. |
| `UVS_USE_HW_ACCEL` | `1` | Enable/disable hardware video acceleration (NVENC, QSV, VAAPI, VideoToolbox). |
| `UVS_PROXY_AUTO_GEN` | `1` | Automatically generate 720p proxies for media $>1080\text{p}$. |
| `UVS_AUTOSAVE_INTERVAL_SEC`| `60` | Checkpoint period for crash recovery journals. |
| `PUB_CACHE` | `/workspace/.pub-cache` | Persisted package cache inside Podman containers. |

---

## 2. Project Settings

Configured per `.uvsp` project under `render_settings`:
* `output_format`: `mp4`, `mkv`, `webm`, `mov`
* `video_codec`: `h264`, `hevc`, `vp9`, `av1`, `prores`
* `audio_codec`: `aac`, `opus`, `mp3`, `pcm`
* `video_bitrate_kbps`: Target video bitrate (e.g. 8000 kbps for 1080p, 25000 kbps for 4K)
* `fps_num` / `fps_den`: Exact rational frame rate
